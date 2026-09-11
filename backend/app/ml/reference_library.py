"""Đọc chuẩn tham chiếu (chuỗi góc trích từ video mẫu) cho từng bài tập,
dùng bởi `SimilarityScorer` để so khớp thời gian thực — xem CHANGELOG
11/09/2026 (3) cho toàn bộ bối cảnh Giai đoạn A/B.

Dữ liệu nguồn là các file JSON do `backend/scripts/extract_reference_poses.py`
sinh ra tại `backend/storage/reference_poses/<bài>.json` (không đi theo git,
giống `exercise_videos`) — chỉ 113/204 bài có chuẩn (xem CHANGELOG), các bài
còn lại KHÔNG có file, và đó là chuyện bình thường chứ không phải lỗi: hàm
`get_reference()` trả `None`, `SimilarityScorer` đọc `None` đó rồi tự tắt
tính năng chấm điểm cho phiên đó — tính năng có tính chất bổ sung (additive),
không được phép làm hỏng phiên tập của bài chưa có chuẩn.

Cache trong RAM theo tiến trình (`functools.lru_cache`): file JSON không đổi
sau khi sinh ra, tính lại chuỗi góc mỗi frame/mỗi phiên là lãng phí CPU vô
ích trên máy 2 vCPU vốn đã chia sẻ cho pose estimation.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app.ml.analyzers.reference_joints import primary_joints_for
from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint

logger = logging.getLogger(__name__)

REFERENCE_DIR = Path(__file__).resolve().parent.parent.parent / "storage" / "reference_poses"


@dataclass(frozen=True)
class ReferenceMotion:
    exercise: str
    analyzer: str
    projection: str  # "x/y" (2D) hoặc "x/y/z" (3D) — đã CHỌN SẴN lúc trích,
    # SimilarityScorer phải dùng lại ĐÚNG phép chiếu này khi tính góc live,
    # không được tự suy luận lại — 2D/3D đúng theo TỪNG VIDEO (xem CHANGELOG
    # 11/09/2026 (3)), không phải hằng số theo họ analyzer.
    angle_series: tuple[float, ...]


def _angle_series_from_frames(
    frames: list[dict], joints: tuple[str, str, str], projection: str
) -> tuple[float, ...]:
    fn = calculate_angle if projection == "x/y" else calculate_angle_3d
    series = []
    for frame in frames:
        a, b, c = (Keypoint(**frame[j]) for j in joints)
        series.append(fn(a, b, c))
    return tuple(series)


@lru_cache(maxsize=256)
def get_reference(exercise: str) -> ReferenceMotion | None:
    """Trả chuẩn tham chiếu cho bài `exercise` (không phân biệt hoa/thường,
    cùng quy ước `exercise.lower()` với `ANALYZER_REGISTRY`) — `None` nếu
    bài đó chưa có chuẩn (chưa được trích, hoặc bị loại vì chất lượng video
    không đạt, xem `extract_reference_poses.py`)."""
    path = REFERENCE_DIR / f"{exercise.lower().replace(' ', '_')}.json"
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        joints = primary_joints_for(data["analyzer"])
        series = _angle_series_from_frames(data["frames"], joints, data["projection"])
    except Exception:
        logger.warning("Không đọc được chuẩn tham chiếu cho '%s'.", exercise, exc_info=True)
        return None
    if len(series) < 2:
        return None
    return ReferenceMotion(
        exercise=data["exercise"],
        analyzer=data["analyzer"],
        projection=data["projection"],
        angle_series=series,
    )
