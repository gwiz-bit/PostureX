"""Phân tích kỹ thuật Leg Extension (duỗi gối máy): độ duỗi, lệch hai bên.

Cùng bộ ba khớp (hông-gối-cổ chân) với `SquatAnalyzer`, nhưng NGƯỢC chiều ưu
tiên: ngồi trên máy, gối gập ~90° là vị trí NGHỈ, duỗi thẳng chân (~170°) là
ĐỈNH rep — nghỉ vốn đã là góc lớn hơn `down_threshold`, khớp đúng giả định
`Phase.TOP` mặc định của `RepCounter`, giống `CalfRaiseAnalyzer` chứ không
giống `LateralRaiseAnalyzer` (không cần góc bù, xem chú thích BẪY GÓC trong
lateral_raise.py).
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc hông-gối-cổ chân ở vị trí nghỉ (ngồi, gối gập) — ƯỚC LƯỢNG theo hình
# học, chưa đo trên người thật, cần hiệu chỉnh qua `ExercisePostureRules`.
KNEE_REST_THRESHOLD = 80.0
# Góc khi đã duỗi thẳng chân hết cỡ (mục tiêu của rep).
KNEE_EXTENDED_THRESHOLD = 165.0
# Chênh lệch góc hai gối quá mức này là duỗi lệch bên.
KNEE_ASYMMETRY_THRESHOLD = 20.0


class LegExtensionAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật leg extension (duỗi gối máy) và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("knee_rest", KNEE_REST_THRESHOLD),
                up_threshold=t.get("knee_extended", KNEE_EXTENDED_THRESHOLD),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]

        left_knee_angle: float | None = None
        right_knee_angle: float | None = None

        if is_visible(left_hip, left_knee, left_ankle):
            left_knee_angle = calculate_angle_3d(left_hip, left_knee, left_ankle)
        if is_visible(right_hip, right_knee, right_ankle):
            right_knee_angle = calculate_angle_3d(right_hip, right_knee, right_ankle)

        knee_angle = avg(left_knee_angle, right_knee_angle)

        phase = self.rep_counter.phase.value
        if knee_angle is not None:
            self.rep_counter.update(knee_angle)
            phase = self.rep_counter.phase.value

            # Mục tiêu của rep là chạm ngưỡng TRÊN (duỗi thẳng chân) — cùng
            # cơ chế `incomplete_lockout` của OverheadPress/Deadlift/HipThrust/
            # CalfRaise (xem CHANGELOG 01/09/2026).
            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa duỗi thẳng chân hết cỡ — đẩy hết biên độ ở đỉnh mỗi rep.")

        if left_knee_angle is not None and right_knee_angle is not None:
            limit = self.threshold("knee_asymmetry", KNEE_ASYMMETRY_THRESHOLD)
            if abs(left_knee_angle - right_knee_angle) > limit:
                errors.append("Hai chân duỗi không đều — giữ tốc độ và độ duỗi hai bên bằng nhau.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_knee=left_knee_angle, right_knee=right_knee_angle),
            phase=phase,
            keypoints=visible_points({
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_knee": left_knee,
                "right_knee": right_knee,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
