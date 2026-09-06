"""Test phân tích tư thế cho video đã upload (`video_analysis_service.py`).

Ba lớp tách biệt, test riêng từng lớp:
  1. `_sample_frame_indices` / `_build_summary` — hàm thuần, test trực tiếp.
  2. `_analyze_keypoint_sequence` — cùng cách 16 analyzer khác được test: bơm
     tư thế dựng sẵn (`tests/pose_builders.py`), không cần video/MediaPipe thật.
  3. `analyze_and_store` — mắt xích tích hợp (mở session DB riêng, đọc/ghi
     bảng `videos`), monkeypatch `AsyncSessionLocal` trỏ về DB SQLite của
     test và giả `_read_sampled_frames`/`_estimate_all` để khỏi cần file
     video thật hay MediaPipe thật — cùng tinh thần `test_realtime_ws.py`.
"""

from collections import Counter

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.ml.pose_estimator import Keypoint
from app.models.video import Video
from app.services import video_analysis_service as vas
from tests.pose_builders import squat_pose
from tests.test_analyzers import rep_sequence

# ─────────────────────────────────────────────────────────────────────
# Hàm thuần
# ─────────────────────────────────────────────────────────────────────

def test_sample_frame_indices_rai_deu_theo_target_fps() -> None:
    # Video 30fps, 3 giây (90 frame), lấy mẫu ~10fps -> stride 3.
    indices = vas._sample_frame_indices(total_frames=90, source_fps=30.0)
    assert indices == list(range(0, 90, 3))


def test_sample_frame_indices_video_rong_hoac_fps_khong_hop_le() -> None:
    assert vas._sample_frame_indices(0, 30.0) == []
    assert vas._sample_frame_indices(90, 0.0) == []


def test_sample_frame_indices_khong_vuot_tran() -> None:
    """Video rất dài vẫn không vượt quá MAX_SAMPLED_FRAMES, và vẫn rải đều
    hết chiều dài video (chỉ số cuối gần cuối video) thay vì cắt đuôi."""
    total_frames = 30 * 3600  # 1 giờ ở 30fps
    indices = vas._sample_frame_indices(total_frames, source_fps=30.0)
    assert len(indices) == vas.MAX_SAMPLED_FRAMES
    assert indices[-1] > total_frames * 0.9  # rải tới gần cuối, không cắt đuôi


# ─────────────────────────────────────────────────────────────────────
# _build_summary
# ─────────────────────────────────────────────────────────────────────

def test_build_summary_khong_loi() -> None:
    summary = vas._build_summary(8, 100.0, Counter())
    assert "8 rep" in summary
    assert "100%" in summary
    assert "Không phát hiện lỗi" in summary


def test_build_summary_co_loi_hay_gap_nhat() -> None:
    counts = Counter({"Lưng bị cúi quá": 5, "Gối trái vượt quá mũi chân": 2})
    summary = vas._build_summary(6, 70.0, counts)
    assert "Lưng bị cúi quá" in summary
    assert "5 lần" in summary


# ─────────────────────────────────────────────────────────────────────
# _analyze_keypoint_sequence — dùng tư thế dựng sẵn, không cần MediaPipe
# ─────────────────────────────────────────────────────────────────────

def test_analyze_keypoint_sequence_dem_dung_rep_va_100_phan_tram() -> None:
    sequence = [squat_pose(a, 175.0) for a in rep_sequence(170, 85, reps=3)]
    reps, accuracy, summary = vas._analyze_keypoint_sequence("squat", sequence, {})
    assert reps == 3
    assert accuracy == 100.0
    assert "3 rep" in summary


def test_analyze_keypoint_sequence_khong_phat_hien_nguoi() -> None:
    sequence: list[list[Keypoint] | None] = [None, None, None]
    reps, accuracy, summary = vas._analyze_keypoint_sequence("squat", sequence, {})
    assert reps == 0
    assert accuracy == 0.0
    assert "Không phát hiện được người" in summary


def test_analyze_keypoint_sequence_bo_qua_frame_khong_phat_hien() -> None:
    """Frame giữa chừng không phát hiện được người (None) không được tính
    vào accuracy — chỉ frame CÓ người mới tính đúng/sai."""
    sequence: list[list[Keypoint] | None] = [
        squat_pose(175.0, 175.0),
        None,
        squat_pose(175.0, 175.0),
    ]
    reps, accuracy, _ = vas._analyze_keypoint_sequence("squat", sequence, {})
    assert accuracy == 100.0


# ─────────────────────────────────────────────────────────────────────
# analyze_and_store — tích hợp, DB SQLite của test + hai hàm cv2 bị giả
# ─────────────────────────────────────────────────────────────────────

@pytest_asyncio.fixture
async def _use_test_db(monkeypatch, db_session: AsyncSession) -> None:
    """Trỏ `AsyncSessionLocal` mà `analyze_and_store` tự mở sang cùng engine
    SQLite của `db_session`, nhưng vẫn là SESSION RIÊNG — đúng thực tế: job
    nền không dùng lại session của request gốc (xem docstring analyze_and_store)."""
    factory = async_sessionmaker(bind=db_session.bind, class_=AsyncSession, expire_on_commit=False)
    monkeypatch.setattr(vas, "AsyncSessionLocal", factory)


async def _make_video(db_session: AsyncSession, exercise: str) -> int:
    video = Video(user_id=1, exercise=exercise, file_path="/khong-can-file-that.mp4")
    db_session.add(video)
    await db_session.commit()
    return video.id


@pytest.mark.usefixtures("_use_test_db")
@pytest.mark.asyncio
async def test_analyze_and_store_ghi_dung_ket_qua(monkeypatch, db_session: AsyncSession) -> None:
    video_id = await _make_video(db_session, "squat")

    monkeypatch.setattr(vas, "_read_sampled_frames", lambda path: (["frame"] * 3, 12.5))

    async def fake_estimate_all(frames):
        # Nội dung frame giả không quan trọng — trả thẳng một rep hoàn chỉnh.
        return [squat_pose(a, 175.0) for a in rep_sequence(170, 85, reps=1)]

    monkeypatch.setattr(vas, "_estimate_all", fake_estimate_all)

    await vas.analyze_and_store(video_id)

    video = (await db_session.execute(select(Video).where(Video.id == video_id))).scalar_one()
    assert video.total_reps == 1
    assert video.accuracy_score == 100.0
    assert video.duration_seconds == 12.5
    assert "1 rep" in video.analysis_summary


@pytest.mark.usefixtures("_use_test_db")
@pytest.mark.asyncio
async def test_analyze_and_store_bai_khong_ho_tro(monkeypatch, db_session: AsyncSession) -> None:
    """Bài không có trong ANALYZER_REGISTRY: KHÔNG rơi về SquatAnalyzer (khác
    routes/realtime.py) — chỉ ghi chú, không đếm rep, không chạy pose
    estimation (tốn CPU vô ích cho bài chắc chắn không phân tích được)."""
    video_id = await _make_video(db_session, "abdominals stretch variation three")

    monkeypatch.setattr(vas, "_read_sampled_frames", lambda path: (["frame"], 5.0))

    async def fail_if_called(frames):
        raise AssertionError("Không được chạy pose estimation cho bài không hỗ trợ.")

    monkeypatch.setattr(vas, "_estimate_all", fail_if_called)

    await vas.analyze_and_store(video_id)

    video = (await db_session.execute(select(Video).where(Video.id == video_id))).scalar_one()
    assert video.total_reps == 0
    assert video.accuracy_score is None
    assert video.duration_seconds == 5.0
    assert "chưa hỗ trợ phân tích" in video.analysis_summary


@pytest.mark.usefixtures("_use_test_db")
@pytest.mark.asyncio
async def test_analyze_and_store_video_khong_doc_duoc(monkeypatch, db_session: AsyncSession) -> None:
    video_id = await _make_video(db_session, "squat")
    monkeypatch.setattr(vas, "_read_sampled_frames", lambda path: ([], 0.0))

    await vas.analyze_and_store(video_id)

    video = (await db_session.execute(select(Video).where(Video.id == video_id))).scalar_one()
    assert video.analysis_summary == "Không đọc được nội dung video."


@pytest.mark.usefixtures("_use_test_db")
@pytest.mark.asyncio
async def test_analyze_and_store_video_da_bi_xoa(db_session: AsyncSession) -> None:
    """Video bị xoá giữa lúc upload xong và lúc job nền chạy tới — không
    được ném lỗi, chỉ bỏ qua trong im lặng (đã log warning)."""
    await vas.analyze_and_store(video_id=999999)
