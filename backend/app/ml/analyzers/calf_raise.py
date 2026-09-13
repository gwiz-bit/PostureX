"""Phân tích kỹ thuật Calf Raise (nhón gót): độ nhón cao, lệch hai bên.

Khớp chính là MẮT CÁ (góc gối-mắt cá-mũi chân), không phải gối hay khuỷu tay
— đứng thẳng bàn chân áp sàn cho góc nhỏ (~90-100°, gần vuông góc), nhón gót
lên cao (gập lòng bàn chân) cho góc lớn (~140-150°). Đỉnh rep là góc LỚN
nhất (đã nhón hết cỡ), giống cơ chế `incomplete_lockout` của OverheadPress/
Deadlift/HipThrust — KHÔNG cần góc bù như `LateralRaiseAnalyzer`, vì ở đây vị
trí nghỉ (đứng phẳng) vốn đã nằm ở phía góc lớn hơn `down_threshold`, khớp
đúng giả định `Phase.TOP` mặc định của `RepCounter` (xem chú thích BẪY GÓC
trong lateral_raise.py — cùng một bẫy, nhưng calf raise không mắc phải).

Hỗ trợ single_side từ 13/09/2026 (đợt 4) cho Dumbbell Single Leg/Single Leg
Standing Calf Raise — dùng `active_side_max()` (`common.py`) thay vì
`active_side()` thường: chân NGHỈ ở bài một chân giữ nguyên góc NHỎ ~90°
(bàn chân áp sàn, đứng yên) — CÙNG PHÍA `down_threshold`, ngược hẳn quy ước
"nghỉ = góc lớn" mà `active_side()` (chọn `min()`) dựa vào. Đọc kỹ docstring
`active_side_max()` trước khi sửa gì ở đây — đây chính là bẫy đã khiến
CalfRaise bị loại hẳn khỏi đợt single_side đầu tiên (xem CHANGELOG
13/09/2026, mục "Nhóm C — thêm chế độ single_side").
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side_max, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc gối-mắt cá-mũi chân ở vị trí nghỉ (đứng phẳng bàn chân) — đặt THẤP HƠN
# góc nghỉ thật (~90-100°) một khoảng an toàn để đứng yên không bị tính nhầm
# là vừa "hạ hết cỡ". ƯỚC LƯỢNG theo hình học, chưa đo trên người thật (cùng
# tình trạng với squat/lunge/deadlift lúc mới viết, xem CHANGELOG
# 01/09/2026) — cần hiệu chỉnh qua `ExercisePostureRules` sau khi test thật.
ANKLE_REST_THRESHOLD = 85.0
# Góc khi đã nhón gót lên cao hết cỡ (mục tiêu của rep).
ANKLE_RAISED_THRESHOLD = 130.0
# Chênh lệch góc hai mắt cá quá mức này là nhón lệch bên.
ANKLE_ASYMMETRY_THRESHOLD = 20.0


class CalfRaiseAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật calf raise (nhón gót) và trả feedback tiếng Việt."""

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
                down_threshold=t.get("ankle_rest", ANKLE_REST_THRESHOLD),
                up_threshold=t.get("ankle_raised", ANKLE_RAISED_THRESHOLD),
            ),
            thresholds,
        )
        # Bài một chân (Dumbbell Single Leg/Single Leg Standing Calf Raise) —
        # xem docstring module: dùng active_side_max() chứ KHÔNG phải
        # active_side() thường, vì quy ước góc ở đây ngược lại. Tắt kiểm tra
        # lệch hai bên khi bật — bài một chân lệch có chủ đích.
        self._single_side = single_side

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_knee = keypoints[25]
        right_knee = keypoints[26]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]
        left_foot = keypoints[31]
        right_foot = keypoints[32]

        left_ankle_angle: float | None = None
        right_ankle_angle: float | None = None

        if is_visible(left_knee, left_ankle, left_foot):
            left_ankle_angle = calculate_angle_3d(left_knee, left_ankle, left_foot)
        if is_visible(right_knee, right_ankle, right_foot):
            right_ankle_angle = calculate_angle_3d(right_knee, right_ankle, right_foot)

        ankle_angle = (
            active_side_max(left_ankle_angle, right_ankle_angle)
            if self._single_side
            else avg(left_ankle_angle, right_ankle_angle)
        )

        phase = self.rep_counter.phase.value
        if ankle_angle is not None:
            self.rep_counter.update(ankle_angle)
            phase = self.rep_counter.phase.value

            # Mục tiêu của rep là chạm ngưỡng TRÊN (đã nhón hết cỡ) — cùng cơ
            # chế `incomplete_lockout` của OverheadPress/Deadlift/HipThrust
            # (xem CHANGELOG 01/09/2026: điều kiện suy từ `phase` cũ tự mâu
            # thuẫn, phải đọc thẳng cờ này).
            if self.rep_counter.incomplete_lockout:
                errors.append("Chưa nhón gót đủ cao — đẩy gót chân lên cao hết cỡ.")

        if (
            not self._single_side
            and left_ankle_angle is not None
            and right_ankle_angle is not None
        ):
            limit = self.threshold("ankle_asymmetry", ANKLE_ASYMMETRY_THRESHOLD)
            if abs(left_ankle_angle - right_ankle_angle) > limit:
                errors.append("Hai bên nhón không đều — giữ tốc độ và độ cao hai gót bằng nhau.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_ankle=left_ankle_angle, right_ankle=right_ankle_angle),
            phase=phase,
            keypoints=visible_points({
                "left_knee": left_knee,
                "right_knee": right_knee,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
