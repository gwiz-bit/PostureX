"""Phân tích kỹ thuật Chest Fly / Pec Fly: độ khép tay, lệch hai bên.

Cùng chỉ số góc với `LateralRaiseAnalyzer` (hông-vai-khuỷu tay) nhưng CHIỀU
NGƯỢC LẠI: chest fly bắt đầu với tay MỞ RỘNG sang hai bên (góc lớn) rồi khép
lại phía trước ngực (góc nhỏ) — đỉnh rep là lúc góc NHỎ nhất, giống cơ chế
curl/row/bench press, không giống lateral raise. Tên trùng chữ "fly" với
lateral raise dễ khiến tưởng nhầm là cùng một analyzer — KHÔNG dùng chung,
xem docstring `lateral_raise.py`.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc hông-vai-khuỷu tay khi đã khép tay hết (đỉnh rep) — ƯỚC LƯỢNG theo hình
# học, chưa đo trên người thật, cần hiệu chỉnh qua `ExercisePostureRules`.
SHOULDER_CONTRACTED_THRESHOLD = 35.0
# Góc khi tay mở rộng hết sang hai bên (vị trí bắt đầu/duỗi).
SHOULDER_EXTENDED_THRESHOLD = 85.0
# Chênh lệch góc hai tay quá mức này là khép lệch bên.
SHOULDER_ASYMMETRY_THRESHOLD = 25.0


class ChestFlyAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật chest/pec fly (khép tay ngực) và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("shoulder_contracted", SHOULDER_CONTRACTED_THRESHOLD),
                up_threshold=t.get("shoulder_extended", SHOULDER_EXTENDED_THRESHOLD),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_elbow = keypoints[13]
        right_elbow = keypoints[14]

        left_shoulder_angle: float | None = None
        right_shoulder_angle: float | None = None

        if is_visible(left_hip, left_shoulder, left_elbow):
            left_shoulder_angle = calculate_angle_3d(left_hip, left_shoulder, left_elbow)
        if is_visible(right_hip, right_shoulder, right_elbow):
            right_shoulder_angle = calculate_angle_3d(right_hip, right_shoulder, right_elbow)

        shoulder_angle = avg(left_shoulder_angle, right_shoulder_angle)

        phase = self.rep_counter.phase.value
        if shoulder_angle is not None:
            self.rep_counter.update(shoulder_angle)
            phase = self.rep_counter.phase.value

            # Đỉnh rep là góc NHỎ nhất (khép tay) — cùng cơ chế
            # `shallow_reversal` của row/bench press/curl.
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa khép tay đủ — kéo hai tay lại gần nhau hơn ở đỉnh.")

        if left_shoulder_angle is not None and right_shoulder_angle is not None:
            limit = self.threshold("shoulder_asymmetry", SHOULDER_ASYMMETRY_THRESHOLD)
            if abs(left_shoulder_angle - right_shoulder_angle) > limit:
                errors.append("Hai tay khép không đều — giữ tốc độ và độ khép hai bên bằng nhau.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_shoulder=left_shoulder_angle, right_shoulder=right_shoulder_angle),
            phase=phase,
            keypoints=visible_points({
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_elbow": left_elbow,
                "right_elbow": right_elbow,
            }),
        )
