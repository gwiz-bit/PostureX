"""Giai đoạn A, Bước 2 — trích "khung xương chuẩn" từ video mẫu cho từng bài,
làm nguyên liệu cho Giai đoạn B (so khớp thời gian thực bằng DTW).

CHƯA CHẠY QUA TOÀN BỘ THƯ VIỆN — mới viết xong, xác nhận công thức qua 3 bài
thử (squat, barbell curl, barbell overhead press) trong phiên trò chuyện, xem
CHANGELOG. Chạy thật cần video mẫu có sẵn tại
`backend/storage/exercise_videos/` (trên VPS) — máy dev thường không có đủ.

CÔNG THỨC ĐÃ XÁC NHẬN (không phải đoán):
- Trích cả góc 2D và 3D cho khớp chính của từng họ analyzer.
- Loại video có tỉ lệ mất dấu người > MISSING_RATE_LIMIT — video mẫu tự nó
  kém thì không đáng tin để làm chuẩn (ca thật: Overhead Press mất dấu 13.3%).
- Giữa 2D/3D, chọn bên có ĐỘ NHẢY TRUNG BÌNH GIỮA HAI FRAME LIÊN TIẾP nhỏ hơn
  (mượt hơn = tín hiệu chuyển động thật, không phải nhiễu) — KHÔNG dùng
  variance tổng, vì nhiễu ngẫu nhiên cũng cho variance cao không kém gì
  chuyển động thật (ca thật: Barbell Curl bị chọn nhầm 2D nếu dùng variance).
  Điều kiện thêm: biên độ (max-min) phải ≥ MIN_RANGE_DEGREES, để loại trường
  hợp góc đó không thấy chuyển động gì (đứng yên vẫn "mượt" theo nghĩa xấu).

Kết quả lưu deliberately ở dạng CHUỖI KEYPOINT ĐẦY ĐỦ (27 khớp, dùng
`pose_estimator.named_keypoints` — cùng tập khớp đã dùng cho khung xương
hiển thị real-time), không chỉ một góc — vì Giai đoạn B cần so cả tư thế,
không riêng một khớp.
"""

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import cv2

from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.ml.pose_estimator import DISPLAY_LANDMARK_NAMES, PoseEstimator, named_keypoints
from app.ml.angle_utils import calculate_angle, calculate_angle_3d

VIDEO_DIR = Path(__file__).resolve().parent.parent / "storage" / "exercise_videos"
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "storage" / "reference_poses"
SAMPLE_FPS = 10.0
MISSING_RATE_LIMIT = 0.10
MIN_RANGE_DEGREES = 20.0

# Bộ ba khớp đại diện để QUYẾT ĐỊNH dùng 2D hay 3D, theo từng họ analyzer —
# không cần chính xác tuyệt đối cho MỌI khớp, chỉ cần đại diện đúng trục
# chuyển động chính của họ đó. Analyzer nào chưa liệt kê thì dùng mặc định
# vai-khuỷu-cổ tay (khớp tay là phổ biến nhất trong 16 analyzer hiện có).
_PRIMARY_JOINTS = {
    "SquatAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LungeAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "DeadliftAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "HipThrustAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "CalfRaiseAnalyzer": ("left_knee", "left_ankle", "left_foot_index"),
    "LegExtensionAnalyzer": ("left_hip", "left_knee", "left_ankle"),
}
_DEFAULT_JOINTS = ("left_shoulder", "left_elbow", "left_wrist")


def _extract(video_path: Path, joints: tuple[str, str, str]):
    estimator = PoseEstimator()
    cap = cv2.VideoCapture(str(video_path))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    stride = max(1, round(fps / SAMPLE_FPS))

    frames_full: list[dict] = []
    angles_2d: list[float] = []
    angles_3d: list[float] = []
    total = missing = idx = 0
    try:
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            if idx % stride == 0:
                total += 1
                ok_enc, buf = cv2.imencode(".jpg", frame)
                keypoints = estimator.estimate(buf.tobytes()) if ok_enc else None
                if keypoints is None:
                    missing += 1
                else:
                    named = named_keypoints(keypoints)
                    frames_full.append({
                        name: {"x": p.x, "y": p.y, "z": p.z, "visibility": p.visibility}
                        for name, p in named.items()
                        if name in DISPLAY_LANDMARK_NAMES
                    })
                    a, b, c = (named[j] for j in joints)
                    angles_2d.append(calculate_angle(a, b, c))
                    angles_3d.append(calculate_angle_3d(a, b, c))
            idx += 1
    finally:
        cap.release()
        estimator.close()

    missing_rate = missing / total if total else 1.0
    return frames_full, angles_2d, angles_3d, missing_rate


def _mean_jump(seq: list[float]) -> float:
    return sum(abs(seq[i] - seq[i - 1]) for i in range(1, len(seq))) / (len(seq) - 1)


def _choose_projection(a2: list[float], a3: list[float]) -> str | None:
    """Trả 'x/y' (2D) hay 'x/y/z' (3D) — None nếu không bên nào đáng tin."""
    if len(a2) < 2:
        return None
    r2, r3 = max(a2) - min(a2), max(a3) - min(a3)
    ok2, ok3 = r2 >= MIN_RANGE_DEGREES, r3 >= MIN_RANGE_DEGREES
    if not ok2 and not ok3:
        return None
    if ok2 and not ok3:
        return "x/y"
    if ok3 and not ok2:
        return "x/y/z"
    return "x/y" if _mean_jump(a2) <= _mean_jump(a3) else "x/y/z"


def build_reference(exercise_name: str) -> dict | None:
    """Dựng chuẩn cho MỘT bài — trả None nếu bài không đủ điều kiện (không có
    video, không có analyzer, hoặc chất lượng video không đạt)."""
    cls = ANALYZER_REGISTRY.get(exercise_name.lower())
    if cls is None:
        return None

    video_path = VIDEO_DIR / f"{exercise_name.lower().replace(' ', '-')}.mp4"
    if not video_path.exists():
        return None

    joints = _PRIMARY_JOINTS.get(cls.__name__, _DEFAULT_JOINTS)
    frames_full, a2, a3, missing_rate = _extract(video_path, joints)
    if missing_rate > MISSING_RATE_LIMIT:
        return None

    projection = _choose_projection(a2, a3)
    if projection is None:
        return None

    return {
        "exercise": exercise_name,
        "analyzer": cls.__name__,
        "projection": projection,
        "missing_rate": round(missing_rate, 3),
        "frames": frames_full,
    }


async def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    built = skipped = 0
    for name in sorted({n for n in ANALYZER_REGISTRY}):
        ref = build_reference(name)
        if ref is None:
            skipped += 1
            continue
        out_path = OUTPUT_DIR / f"{name.replace(' ', '_')}.json"
        out_path.write_text(json.dumps(ref, ensure_ascii=False), encoding="utf-8")
        built += 1
        print(f"OK  {name} -> {ref['projection']}")
    print(f"\nDa dung {built} chuan, bo qua {skipped} bai (thieu video/chat luong khong dat).")


if __name__ == "__main__":
    asyncio.run(main())
