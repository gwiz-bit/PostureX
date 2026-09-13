"""Phân tích kỹ thuật Leg Curl (gập gối máy — nằm/ngồi/đứng): độ co, lệch hai bên.

Cùng bộ ba khớp (hông-gối-cổ chân) với `SquatAnalyzer`/`LegExtensionAnalyzer`
nhưng khác cả hai: máy leg curl kéo chân về DUỖI THẲNG khi không gồng (giống
cơ chế lò xo của máy curl tay), nên NGHỈ = góc LỚN (~170-180°, chân duỗi),
CO HẾT (gót chạm mông) = góc NHỎ (~30-50°) — cùng chiều `CurlAnalyzer`/
`RowAnalyzer`, KHÔNG giống `LegExtensionAnalyzer`/`CalfRaiseAnalyzer` (nghỉ =
góc nhỏ). Không phụ thuộc tư thế nằm sấp/ngồi/đứng — công thức góc hông-gối-
cổ chân không quan tâm hướng thân, cùng lý do `BenchPressAnalyzer` không
phụ thuộc tư thế nằm/đứng.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc hông-gối-cổ chân khi đã co hết (gót gần chạm mông) — ƯỚC LƯỢNG theo
# hình học, chưa đo trên người thật, cần hiệu chỉnh qua `ExercisePostureRules`.
KNEE_CONTRACTED_THRESHOLD = 50.0
# Góc khi chân duỗi thẳng hoàn toàn (vị trí nghỉ/bắt đầu).
KNEE_EXTENDED_THRESHOLD = 165.0
# Chênh lệch góc hai gối quá mức này là co lệch bên.
KNEE_ASYMMETRY_THRESHOLD = 20.0


class LegCurlAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật leg curl (gập gối máy) và trả feedback tiếng Việt."""

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
                down_threshold=t.get("knee_contracted", KNEE_CONTRACTED_THRESHOLD),
                up_threshold=t.get("knee_extended", KNEE_EXTENDED_THRESHOLD),
            ),
            thresholds,
        )
        self._single_side = single_side

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

        knee_angle = (
            active_side(left_knee_angle, right_knee_angle)
            if self._single_side
            else avg(left_knee_angle, right_knee_angle)
        )

        phase = self.rep_counter.phase.value
        if knee_angle is not None:
            self.rep_counter.update(knee_angle)
            phase = self.rep_counter.phase.value

            # Đỉnh rep là góc NHỎ nhất (gót gần chạm mông) — cùng cơ chế
            # shallow_reversal của curl/row (CHANGELOG 01/09/2026).
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa gập gối đủ sâu — kéo gót chân gần mông hơn ở đỉnh mỗi rep.")

        if not self._single_side and left_knee_angle is not None and right_knee_angle is not None:
            limit = self.threshold("knee_asymmetry", KNEE_ASYMMETRY_THRESHOLD)
            if abs(left_knee_angle - right_knee_angle) > limit:
                errors.append("Hai chân co không đều — giữ tốc độ và độ co hai bên bằng nhau.")

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
