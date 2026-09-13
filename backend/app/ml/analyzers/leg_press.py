"""Phân tích kỹ thuật Leg Press (đẩy chân máy — ngồi/nằm nghiêng): độ duỗi, lệch hai bên.

Cùng bộ ba khớp (hông-gối-cổ chân) với `SquatAnalyzer`, nhưng ngồi/nằm tựa
lưng vào máy nên KHÔNG kiểm gối vượt mũi chân (`KNEE_OVERSHOOT_RATIO` của
squat giả định đứng, camera nhìn từ bên — không áp dụng cho tư thế ngồi/
nằm của leg press) và KHÔNG kiểm lưng thẳng (lưng đã tựa cố định vào đệm).
Đỉnh rep là DUỖI CHÂN HẾT CỠ (đẩy bàn đạp ra xa) — cùng chiều
`LegExtensionAnalyzer`/`CalfRaiseAnalyzer` (nghỉ = góc nhỏ hơn, đỉnh = lớn).

CỐ TÌNH CHƯA hỗ trợ `single_side` (khác các analyzer khác thêm 13/09/2026):
chân "nghỉ" của Single Leg Press không có vị trí tự nhiên rõ ràng (không đặt
trên bàn đạp, có thể để tuỳ ý sang một bên) — không đủ tin cậy để
`active_side()` chọn đúng chân đang đẩy, khác các bài tay (tay nghỉ luôn
duỗi thẳng bên hông) hay Cable Single Leg Laying Leg Curl (chân nghỉ vẫn
nằm duỗi thẳng trên ghế). Cần rà thêm trước khi bật.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc hông-gối-cổ chân ở vị trí nghỉ (bàn đạp gần ngực/bụng) — ƯỚC LƯỢNG theo
# hình học, chưa đo trên người thật, cần hiệu chỉnh qua `ExercisePostureRules`.
KNEE_REST_THRESHOLD = 85.0
# Góc khi đã duỗi chân gần hết cỡ (mục tiêu của rep — KHÔNG khoá thẳng hoàn
# toàn 180° để tránh cổ vũ khoá gối, chỉ cần đủ gần).
KNEE_EXTENDED_THRESHOLD = 160.0
# Chênh lệch góc hai gối quá mức này là đẩy lệch bên.
KNEE_ASYMMETRY_THRESHOLD = 20.0


class LegPressAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật leg press (đẩy chân máy) và trả feedback tiếng Việt."""

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

            # Mục tiêu của rep là chạm ngưỡng TRÊN (duỗi chân hết cỡ) — cùng
            # cơ chế incomplete_lockout của LegExtension/CalfRaise/OverheadPress
            # (CHANGELOG 01/09/2026).
            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa duỗi chân đủ — đẩy bàn đạp ra xa hơn ở đỉnh mỗi rep.")

        if left_knee_angle is not None and right_knee_angle is not None:
            limit = self.threshold("knee_asymmetry", KNEE_ASYMMETRY_THRESHOLD)
            if abs(left_knee_angle - right_knee_angle) > limit:
                errors.append("Hai chân đẩy không đều — giữ tốc độ và độ duỗi hai bên bằng nhau.")

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
