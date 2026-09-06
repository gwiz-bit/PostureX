"""Phân tích tư thế cho video người dùng đã upload.

TRƯỚC ĐÂY: `POST /videos/upload` chỉ lưu file + tạo bản ghi metadata rồi
dừng — `total_reps`, `accuracy_score`, `analysis_summary` luôn giữ giá trị
mặc định (0/None/None), không bao giờ được ghi (xem CLAUDE.md, mục "Bố cục
backend"). Module này lấp đúng chỗ trống đó, chạy NGẦM sau khi upload xong
(xem `routes/videos.py`), không chặn response trả về cho client.

TÁI DÙNG TOÀN BỘ HẠ TẦNG PHÂN TÍCH REAL-TIME
---------------------------------------------
Không viết lại logic phân tích — dùng lại nguyên `ANALYZER_REGISTRY`,
`ExercisePostureRules` (qua `load_thresholds`), và `SessionState` mà
`routes/realtime.py` đã dùng cho WebSocket. Khác biệt duy nhất: nguồn frame
là file video đọc bằng `cv2.VideoCapture` thay vì luồng JPEG từ client, và
phân tích chạy TUẦN TỰ hết video một lần thay vì từng frame theo thời gian
thực. Bài không có trong `ANALYZER_REGISTRY` thì KHÔNG dùng squat mặc định
(khác `routes/realtime.py`) — client offer nút upload cho MỌI bài kể cả bài
không hỗ trợ phân tích, nên rơi vào SquatAnalyzer sẽ đọc feedback squat sai
hoàn toàn cho một bài duỗi cơ hay bài cổ.

CHIA TÁCH ĐỂ TEST ĐƯỢC
------------------------
`_analyze_keypoint_sequence` là phần logic THUẦN (không cv2/mediapipe) —
tách riêng để test bằng tư thế dựng sẵn (`tests/pose_builders.py`), đúng
cách 16 analyzer khác được test (`tests/test_analyzers.py`), thay vì phải có
file video thật + chạy MediaPipe thật trong bộ test.
"""

import asyncio
import logging
from collections import Counter

import cv2
from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.ml.analyzers.thresholds import load_thresholds
from app.ml.pose_estimator import Keypoint
from app.ml.pose_estimator_pool import get_pose_estimator_pool
from app.ml.session_state import SessionState
from app.models.video import Video

logger = logging.getLogger(__name__)

# Nhịp lấy mẫu nhắm tới — gần với tốc độ client gửi frame lúc phân tích
# real-time (~9 fps, xem routes/realtime.py), không cần dày hơn.
TARGET_SAMPLE_FPS = 10.0
# Trần số frame lấy mẫu cho MỘT video, bất kể video dài bao lâu. Video tối đa
# 50MB (xem video_service.py) vẫn có thể dài vài phút ở bitrate thấp — không
# giới hạn thì một video dài có thể chiếm pool pose-estimation hàng chục giây
# liền, làm chậm người đang tập real-time dùng CHUNG pool đó.
MAX_SAMPLED_FRAMES = 400


def _sample_frame_indices(total_frames: int, source_fps: float) -> list[int]:
    """Chỉ số frame cần lấy mẫu, rải đều theo `TARGET_SAMPLE_FPS`.

    Vượt quá `MAX_SAMPLED_FRAMES` thì rải lại đều trên tập đã chọn thay vì
    cắt đuôi — cắt đuôi sẽ bỏ mất nửa sau video, rải đều vẫn phủ trọn video.
    """
    if total_frames <= 0 or source_fps <= 0:
        return []
    stride = max(1, round(source_fps / TARGET_SAMPLE_FPS))
    indices = list(range(0, total_frames, stride))
    if len(indices) > MAX_SAMPLED_FRAMES:
        step = len(indices) / MAX_SAMPLED_FRAMES
        indices = [indices[int(i * step)] for i in range(MAX_SAMPLED_FRAMES)]
    return indices


def _read_sampled_frames(path: str) -> tuple[list[bytes], float]:
    """Đọc video, trả (frame JPEG đã lấy mẫu, thời lượng giây).

    Đồng bộ và tốn CPU (`cv2.VideoCapture` là blocking I/O) — luôn gọi qua
    `asyncio.to_thread` từ phía caller, không gọi trực tiếp trong hàm async.
    """
    cap = cv2.VideoCapture(path)
    try:
        if not cap.isOpened():
            return [], 0.0

        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = cap.get(cv2.CAP_PROP_FPS) or 0.0
        duration = total_frames / fps if fps > 0 else 0.0

        wanted = set(_sample_frame_indices(total_frames, fps))
        if not wanted:
            return [], duration

        frames: list[bytes] = []
        last_wanted = max(wanted)
        index = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if index in wanted:
                ok_encode, buf = cv2.imencode(".jpg", frame)
                if ok_encode:
                    frames.append(buf.tobytes())
            if index >= last_wanted:
                break
            index += 1
        return frames, duration
    finally:
        cap.release()


async def _estimate_all(frames: list[bytes]) -> list[list[Keypoint] | None]:
    """Chạy pose estimation cho từng frame qua pool dùng chung, TUẦN TỰ.

    Cố tình không `asyncio.gather` chạy song song: pool giới hạn N luồng
    dùng CHUNG với các phiên WebSocket live (`get_pose_estimator_pool`), một
    video chiếm hết N luồng cùng lúc sẽ chặn người đang tập thật. Chờ tuần
    tự ở đây đẩy video vào hàng đợi công bằng như mọi request khác.
    """
    pool = get_pose_estimator_pool()
    results: list[list[Keypoint] | None] = []
    for frame in frames:
        results.append(await pool.estimate(frame))
    return results


def _build_summary(reps: int, accuracy: float, error_counts: Counter[str]) -> str:
    base = f"Đã phân tích {reps} rep, độ chính xác {accuracy:.0f}%."
    if not error_counts:
        return base + " Không phát hiện lỗi kỹ thuật nào."
    top_error, count = error_counts.most_common(1)[0]
    return f"{base} Lỗi hay gặp nhất: {top_error} ({count} lần)."


def _analyze_keypoint_sequence(
    exercise: str,
    keypoints_sequence: list[list[Keypoint] | None],
    thresholds: dict[str, float],
) -> tuple[int, float, str]:
    """Chạy analyzer qua cả chuỗi keypoint, trả (total_reps, accuracy, summary).

    Giả định `exercise` ĐÃ có trong `ANALYZER_REGISTRY` — caller (`analyze_and_store`)
    chịu trách nhiệm kiểm trước, để không tốn công đọc/ước lượng frame cho
    một bài chắc chắn không phân tích được.
    """
    cls = ANALYZER_REGISTRY[exercise.lower()]
    analyzer = cls(thresholds=thresholds)
    session = SessionState(exercise)
    error_counts: Counter[str] = Counter()
    detected_frames = 0

    for keypoints in keypoints_sequence:
        if keypoints is None:
            continue
        detected_frames += 1
        result = analyzer.analyze(keypoints)
        session.record_frame(result.errors)
        error_counts.update(result.errors)

    if detected_frames == 0:
        return 0, 0.0, (
            "Không phát hiện được người trong video — thử quay lại với ánh "
            "sáng tốt hơn và để toàn thân trong khung hình."
        )

    reps = analyzer.rep_counter.rep_count
    return reps, session.accuracy, _build_summary(reps, session.accuracy, error_counts)


async def analyze_and_store(video_id: int) -> None:
    """Điểm vào chạy nền sau khi upload xong (xem `routes/videos.py`).

    Mở session DB RIÊNG thay vì tái dùng session của request gốc: FastAPI
    `BackgroundTasks` chạy SAU khi response đã gửi, lúc đó session của
    request đã đóng — dùng lại sẽ ném lỗi session-closed.
    """
    async with AsyncSessionLocal() as db:
        video = (
            await db.execute(select(Video).where(Video.id == video_id))
        ).scalar_one_or_none()
        if video is None:
            logger.warning("Video id=%s không còn tồn tại, bỏ qua phân tích.", video_id)
            return

        try:
            frames, duration = await asyncio.to_thread(_read_sampled_frames, video.file_path)
        except Exception:
            logger.exception("Lỗi đọc video id=%s để phân tích.", video_id)
            return

        video.duration_seconds = duration

        if video.exercise.lower() not in ANALYZER_REGISTRY:
            video.analysis_summary = "Bài này chưa hỗ trợ phân tích tự động — video chỉ được lưu lại."
            await db.commit()
            return

        if not frames:
            video.analysis_summary = "Không đọc được nội dung video."
            await db.commit()
            return

        thresholds = await load_thresholds(db, video.exercise)
        keypoints_sequence = await _estimate_all(frames)
        total_reps, accuracy, summary = _analyze_keypoint_sequence(
            video.exercise, keypoints_sequence, thresholds
        )

        video.total_reps = total_reps
        video.accuracy_score = accuracy
        video.analysis_summary = summary
        await db.commit()
        logger.info(
            "Đã phân tích video id=%s (%s): %d rep, %.1f%% chính xác.",
            video_id, video.exercise, total_reps, accuracy,
        )
