"""Phân tích kỹ thuật Deadlift: gập/duỗi hông (hip hinge), gối không vượt mũi chân.

Hỗ trợ single_side từ 13/09/2026 cho họ single-leg Romanian Deadlift ĐÚNG kiểu
"chân sau duỗi thẳng, thân-hông-chân sau tạo thành một đường thẳng" (Single Leg
Dumbbell/Kettlebell Deficit/Single Legged) — xem docstring tham số `single_side`
bên dưới. KHÔNG áp cho mọi biến thể một chân: Kickstand Dumbbell Romanian
Deadlift dùng tư thế "kiềng" (chân sau chỉ chạm nhẹ gần sàn để giữ thăng bằng,
không duỗi thẳng ra sau thành một đường), nên góc vai-hông-gối của chân đó
KHÔNG giữ ổn định ở vùng góc lớn suốt bài như giả định của `active_side()` —
để dành, chưa đủ tự tin. Dumbbell Cross Body Romanian Deadlift có xoay thân
(reach tay chéo sang chân đối diện) — nằm trong giới hạn chung "không đo được
xoay quanh trục dọc" của cả dự án, không liên quan single_side.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
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

    SUPPORTS_SINGLE_SIDE = True

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
        single_side: bool = False,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("hip_down", HIP_HINGE_DOWN_THRESHOLD),
                up_threshold=t.get("hip_up", HIP_HINGE_UP_THRESHOLD),
            ),
            thresholds,
        )
        # Bài single-leg RDL (xem docstring module) — chân trụ (đang chịu lực)
        # là bên có góc vai-hông-gối NHỎ HƠN tại từng thời điểm: chân sau nhấc
        # lên duỗi thẳng ra sau tạo thành một đường thẳng với thân, nên góc
        # phía đó gần như giữ nguyên ~170-180° suốt bài — an toàn cho
        # `active_side()`, cùng lý do đã dùng cho HipThrust/HipAbduction.
        self._single_side = single_side

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

        hip_angle = (
            active_side(left_hip_angle, right_hip_angle)
            if self._single_side
            else avg(left_hip_angle, right_hip_angle)
        )

        phase = self.rep_counter.phase.value
        if hip_angle is not None:
            self.rep_counter.update(hip_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa đứng thẳng hoàn toàn — duỗi hông hết cỡ ở đỉnh động tác.")

        overshoot = self.threshold("knee_overshoot", KNEE_OVERSHOOT_RATIO)
        if is_visible(left_knee, left_foot):
            if left_knee.x > left_foot.x + overshoot:
                errors.append("Gối trái vượt quá mũi chân — đẩy hông về sau nhiều hơn thay vì gập gối.")
        if is_visible(right_knee, right_foot):
            if right_knee.x < right_foot.x - overshoot:
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
