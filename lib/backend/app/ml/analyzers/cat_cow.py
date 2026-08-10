"""Phân tích động tác Cat-Cow: đếm chu kỳ cong lưng (Cat) / ưỡn lưng (Cow)."""

from app.ml.angle_utils import calculate_angle
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import is_visible, visible_points
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc vai-hông-gối nhỏ = lưng cong tròn (tư thế Cat) — coi là "đáy" của chu kỳ.
# Góc lớn = lưng ưỡn cong ngược (tư thế Cow) — coi là "đỉnh" của chu kỳ.
# Đây là bài mobility nhẹ nhàng nên không có "lỗi kỹ thuật" để cảnh báo,
# analyzer chỉ đếm số chu kỳ đã hoàn thành để người dùng theo dõi tiến độ.
CAT_THRESHOLD = 140.0
COW_THRESHOLD = 165.0


class CatCowAnalyzer(ExerciseAnalyzer):
    """Phân tích động tác Cat-Cow — chỉ đếm chu kỳ, không có cảnh báo lỗi."""

    def __init__(self, rep_counter: RepCounter | None = None) -> None:
        super().__init__(
            rep_counter or RepCounter(down_threshold=CAT_THRESHOLD, up_threshold=COW_THRESHOLD)
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]

        back_angle: float | None = None
        left_ok = is_visible(left_shoulder, left_hip, left_knee)
        right_ok = is_visible(right_shoulder, right_hip, right_knee)

        if left_ok:
            back_angle = calculate_angle(left_shoulder, left_hip, left_knee)
        elif right_ok:
            back_angle = calculate_angle(right_shoulder, right_hip, right_knee)

        phase = self.rep_counter.phase.value
        if back_angle is not None:
            self.rep_counter.update(back_angle)
            phase = self.rep_counter.phase.value

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=[],
            correct=True,
            key_angles=KeyAngles(back_angle=back_angle),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_knee": left_knee,
                "right_knee": right_knee,
            }),
        )
