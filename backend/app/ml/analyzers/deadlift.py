"""Phân tích kỹ thuật Deadlift: gập/duỗi hông (hip hinge), gối không vượt mũi chân."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Deadlift là động tác gập/duỗi HÔNG — khác squat (gập/duỗi GỐI là chính).
# Góc hông (vai-hông-gối) nhỏ ở đáy (cúi người) và lớn khi đứng thẳng.
HIP_HINGE_DOWN_THRESHOLD = 110.0   # Góc hông ≤ ngưỡng này mới coi là đã cúi đủ để nắm tạ
HIP_HINGE_UP_THRESHOLD = 165.0     # Góc hông ≥ ngưỡng này mới coi là đã đứng thẳng hoàn toàn
KNEE_OVERSHOOT_RATIO = 0.05        # Gối không được vượt qua mũi chân quá 5% chiều rộng frame


class DeadliftAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật deadlift và trả feedback tiếng Việt."""

    def __init__(self, rep_counter: RepCounter | None = None) -> None:
        super().__init__(
            rep_counter
            or RepCounter(down_threshold=HIP_HINGE_DOWN_THRESHOLD, up_threshold=HIP_HINGE_UP_THRESHOLD)
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]
        left_foot = keypoints[31]
        right_foot = keypoints[32]

        left_hip_angle: float | None = None
        right_hip_angle: float | None = None
        left_hip_ok = is_visible(left_shoulder, left_hip, left_knee)
        right_hip_ok = is_visible(right_shoulder, right_hip, right_knee)

        if left_hip_ok:
            left_hip_angle = calculate_angle_3d(left_shoulder, left_hip, left_knee)
        if right_hip_ok:
            right_hip_angle = calculate_angle_3d(right_shoulder, right_hip, right_knee)

        hip_angle = avg(left_hip_angle, right_hip_angle)

        phase = self.rep_counter.phase.value
        if hip_angle is not None:
            self.rep_counter.update(hip_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa đứng thẳng hoàn toàn — duỗi hông hết cỡ ở đỉnh động tác.")

        if is_visible(left_knee, left_foot):
            if left_knee.x > left_foot.x + KNEE_OVERSHOOT_RATIO:
                errors.append("Gối trái vượt quá mũi chân — đẩy hông về sau nhiều hơn thay vì gập gối.")
        if is_visible(right_knee, right_foot):
            if right_knee.x < right_foot.x - KNEE_OVERSHOOT_RATIO:
                errors.append("Gối phải vượt quá mũi chân — đẩy hông về sau nhiều hơn thay vì gập gối.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(
                left_hip=left_hip_angle,
                right_hip=right_hip_angle,
                back_angle=hip_angle,
            ),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_knee": left_knee,
                "right_knee": right_knee,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
