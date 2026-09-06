"""Phân tích kỹ thuật Pulldown/Pull-up (kéo dọc): độ co, lệch hai bên.

Gộp chung Lat Pulldown (kéo tạ xuống) và Pull-up/Chin-up (kéo thân lên) vào
MỘT analyzer vì cả hai cùng một cơ chế góc khuỷu tay — chỉ khác vật nào di
chuyển (tạ hay thân người), còn khuỷu tay đều đi từ duỗi gần thẳng (treo/với
tay lên xà) tới gập sâu (tạ chạm ngực / cằm qua xà).

CỐ TÌNH KHÔNG kiểm lưng thẳng như `RowAnalyzer`: pulldown ngồi trên máy có
chân gập ra trước (không phải đứng cúi người như row), nên góc vai-hông-gối
tự nhiên chỉ còn ~90-100° dù ngồi đúng tư thế — sát ngay ngưỡng 100° của Row,
dễ báo nhầm "lưng cong" cho người ngồi bình thường. Không có kiểm lưng nào ở
đây, chỉ góc khuỷu tay + lệch hai bên.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là đã kéo hết (tạ chạm ngực / cằm qua xà).
ELBOW_CONTRACTED_THRESHOLD = 65.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã về vị trí bắt đầu (tay gần thẳng,
# treo người hoặc với tay lên xà/thanh kéo).
ELBOW_EXTENDED_THRESHOLD = 160.0
# Chênh lệch góc hai tay quá mức này là kéo lệch bên.
ELBOW_ASYMMETRY_THRESHOLD = 25.0


class PulldownAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật pulldown/pull-up (kéo dọc) và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("elbow_contracted", ELBOW_CONTRACTED_THRESHOLD),
                up_threshold=t.get("elbow_extended", ELBOW_EXTENDED_THRESHOLD),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_elbow = keypoints[13]
        right_elbow = keypoints[14]
        left_wrist = keypoints[15]
        right_wrist = keypoints[16]

        left_elbow_angle: float | None = None
        right_elbow_angle: float | None = None

        if is_visible(left_shoulder, left_elbow, left_wrist):
            left_elbow_angle = calculate_angle_3d(left_shoulder, left_elbow, left_wrist)
        if is_visible(right_shoulder, right_elbow, right_wrist):
            right_elbow_angle = calculate_angle_3d(right_shoulder, right_elbow, right_wrist)

        elbow_angle = avg(left_elbow_angle, right_elbow_angle)

        phase = self.rep_counter.phase.value
        if elbow_angle is not None:
            self.rep_counter.update(elbow_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa kéo hết — gập khuỷu tay nhiều hơn ở đỉnh mỗi rep.")

        if left_elbow_angle is not None and right_elbow_angle is not None:
            limit = self.threshold("elbow_asymmetry", ELBOW_ASYMMETRY_THRESHOLD)
            if abs(left_elbow_angle - right_elbow_angle) > limit:
                errors.append("Hai tay kéo không đều — giữ tốc độ và độ co hai bên bằng nhau.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_elbow=left_elbow_angle, right_elbow=right_elbow_angle),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_elbow": left_elbow,
                "right_elbow": right_elbow,
                "left_wrist": left_wrist,
                "right_wrist": right_wrist,
            }),
        )
