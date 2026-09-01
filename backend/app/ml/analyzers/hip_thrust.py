"""Phân tích kỹ thuật Hip Thrust: nâng/hạ hông (duỗi hông), hai bên đều nhau."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Cùng công thức góc hông (vai-hông-gối) như deadlift, nhưng ngữ cảnh khác:
# nằm ngửa, vai tựa ghế/sàn, hông đẩy lên — đáy là hông hạ thấp, đỉnh là
# hông duỗi thẳng hàng với vai và gối.
HIP_DOWN_THRESHOLD = 110.0
HIP_UP_THRESHOLD = 165.0
HIP_ASYMMETRY_THRESHOLD = 15.0   # Chênh lệch góc hông hai bên quá mức này là đẩy lệch bên


class HipThrustAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật hip thrust và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("hip_down", HIP_DOWN_THRESHOLD),
                up_threshold=t.get("hip_up", HIP_UP_THRESHOLD),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]

        left_hip_angle: float | None = None
        right_hip_angle: float | None = None

        if is_visible(left_shoulder, left_hip, left_knee):
            left_hip_angle = calculate_angle_3d(left_shoulder, left_hip, left_knee)
        if is_visible(right_shoulder, right_hip, right_knee):
            right_hip_angle = calculate_angle_3d(right_shoulder, right_hip, right_knee)

        hip_angle = avg(left_hip_angle, right_hip_angle)

        phase = self.rep_counter.phase.value
        if hip_angle is not None:
            self.rep_counter.update(hip_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa đẩy hông lên hết — siết mông, duỗi hông thẳng hàng vai-hông-gối.")

        if left_hip_angle is not None and right_hip_angle is not None:
            limit = self.threshold("hip_asymmetry", HIP_ASYMMETRY_THRESHOLD)
            if abs(left_hip_angle - right_hip_angle) > limit:
                errors.append("Hông đang lệch một bên — đẩy đều lực cả hai bên mông.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_hip=left_hip_angle, right_hip=right_hip_angle, back_angle=hip_angle),
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
