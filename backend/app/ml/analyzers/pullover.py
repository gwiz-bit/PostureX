"""Phân tích kỹ thuật Pullover: độ kéo tay về ngực, lệch hai bên.

Cùng bộ ba khớp (hông-vai-khuỷu tay) với `LateralRaiseAnalyzer`/
`ChestFlyAnalyzer` — khớp chính di chuyển là VAI (khuỷu tay giữ gập nhẹ, gần
cố định suốt rep), nhưng khác cả hai về MẶT PHẲNG chuyển động: pullover đưa
tay từ phía SAU ĐẦU (duỗi qua đầu) vòng cung xuống phía TRƯỚC NGỰC, không
phải sang ngang (lateral raise) hay khép trước ngực từ hai bên (chest fly).

Vị trí bắt đầu (tay duỗi qua đầu) cho góc hông-vai-khuỷu tay LỚN (cánh tay
gần như ngược hướng với thân dưới); kéo tay về phía đùi/ngực (đỉnh rep) cho
góc NHỎ — cùng chiều `CurlAnalyzer`/`TricepExtensionAnalyzer` (nghỉ = lớn,
làm việc = nhỏ), không cần góc bù như `LateralRaiseAnalyzer`.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc hông-vai-khuỷu tay khi đã kéo tay về đỉnh (gần đùi/ngực) — ƯỚC LƯỢNG
# theo hình học, chưa đo trên người thật, cần hiệu chỉnh qua
# `ExercisePostureRules`.
SHOULDER_CONTRACTED_THRESHOLD = 60.0
# Góc khi tay duỗi qua đầu hết cỡ (vị trí bắt đầu/nghỉ).
SHOULDER_EXTENDED_THRESHOLD = 150.0
# Chênh lệch góc hai tay quá mức này là kéo lệch bên.
SHOULDER_ASYMMETRY_THRESHOLD = 25.0


class PulloverAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật pullover (kéo tay qua đầu về ngực) và trả feedback tiếng Việt."""

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

            # Đỉnh rep là góc NHỎ nhất (tay kéo về gần đùi/ngực) — cùng cơ
            # chế shallow_reversal của curl/tricep extension.
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa kéo tay đủ — kéo tay về gần đùi/ngực hơn ở đỉnh mỗi rep.")

        if left_shoulder_angle is not None and right_shoulder_angle is not None:
            limit = self.threshold("shoulder_asymmetry", SHOULDER_ASYMMETRY_THRESHOLD)
            if abs(left_shoulder_angle - right_shoulder_angle) > limit:
                errors.append("Hai tay kéo không đều — giữ tốc độ và độ kéo hai bên bằng nhau.")

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
