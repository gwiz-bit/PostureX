"""Phân tích kỹ thuật Overhead Press: đẩy tạ thẳng qua đầu, khoá tay đủ ở đỉnh."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

ELBOW_DOWN_THRESHOLD = 90.0        # Khuỷu tay gập ≤ ngưỡng này = vị trí bắt đầu (tạ ngang vai)
ELBOW_LOCKOUT_THRESHOLD = 160.0    # Khuỷu tay duỗi ≥ ngưỡng này = đã đẩy thẳng tay qua đầu
ELBOW_ASYMMETRY_THRESHOLD = 25.0   # Chênh lệch góc hai tay quá mức này là đẩy lệch bên


class OverheadPressAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật overhead press (đẩy vai) và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("elbow_down", ELBOW_DOWN_THRESHOLD),
                up_threshold=t.get("elbow_lockout", ELBOW_LOCKOUT_THRESHOLD),
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

            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa khoá tay hoàn toàn ở đỉnh — đẩy tạ thẳng hết cỡ qua đầu.")

        if left_elbow_angle is not None and right_elbow_angle is not None:
            limit = self.threshold("elbow_asymmetry", ELBOW_ASYMMETRY_THRESHOLD)
            if abs(left_elbow_angle - right_elbow_angle) > limit:
                errors.append("Hai tay đẩy tạ không đều — giữ tốc độ và độ cao hai bên bằng nhau.")

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
