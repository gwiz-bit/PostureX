"""Phân tích kỹ thuật Glute Kickback (Cable/Machine): duỗi hông ra sau, luôn
một chân.

Cùng bộ ba khớp (vai-hông-gối) và `calculate_angle_3d` với các analyzer hông
khác (`DeadliftAnalyzer`/`HipThrustAnalyzer`/`HipAbductionAnalyzer`), nhưng đo
một chuyển động NGƯỢC: kickback bắt đầu ở tư thế hông gập nhẹ (chân đang tập
đứng dưới thân — dù đứng bên máy, quỳ hay tựa ghế, thân đều cúi/nghiêng về
phía trước một góc nào đó) rồi CHỦ ĐỘNG duỗi hông ra sau hết cỡ. Đỉnh rep là
lúc vai-hông-chân gần thẳng hàng thành MỘT ĐƯỜNG THẲNG — cùng hình học "thân
và chân sau thẳng hàng" đã xác nhận an toàn cho single-leg Romanian Deadlift
(xem CHANGELOG 13/09/2026), chỉ khác là torso ở đây có thể cúi/nghiêng ở bất
kỳ góc nào (đứng bên máy cáp, quỳ trên ghế, hay tựa nằm sấp) — `calculate_angle_3d`
đo góc 3D thật giữa hai vector nên không phụ thuộc torso đang nghiêng bao
nhiêu độ, cùng nguyên lý đã xác nhận cho `HipAbductionAnalyzer` không phụ
thuộc góc camera.

BẪY GÓC — giống hệt LateralRaiseAnalyzer/HipAdductionAnalyzer (đọc docstring
hai class đó trước khi sửa): NGHỈ (chân đứng dưới thân, hông mới gập nhẹ) có
góc thô NHỎ HƠN đỉnh rep (chân duỗi ra sau hết cỡ, gần thẳng hàng thân) —
ngược quy ước mặc định của `RepCounter` (giả định nghỉ = góc LỚN). Dùng góc bù
`180 - raw` để đếm rep.

LUÔN single_side=True: cơ chế bài này vốn luôn kick TỪNG CHÂN một, không có
biến thể hai chân đồng thời trong thư viện. Chân trụ (đứng/quỳ yên giữ thăng
bằng) dao động quanh vùng góc "nghỉ" suốt bài, không trôi xa tới vùng "đỉnh
rep" (gần thẳng hàng) của chân đang kick — nên `active_side()` trên góc ĐÃ BÙ
vẫn chọn đúng chân đang làm việc mỗi khi nó vượt qua chân trụ, cùng cách
RowAnalyzer/CurlAnalyzer dùng `active_side()` cho bài một tay.

Gộp chung ba bài Cable Bench Straight Leg Kickback (tựa ghế), Cable Kickback
(đứng cúi người bên máy cáp) và Glute Kickback Machine (đứng/tựa máy đẩy bàn
đạp) vì cùng MỘT cơ chế duỗi hông ra sau, chỉ khác tư thế đỡ thân — đúng lý do
`BenchPressAnalyzer` gộp cả tư thế nằm lẫn đứng (xem docstring class đó).
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc thô (vai-hông-gối) khi đã duỗi hông ra sau hết cỡ (đỉnh rep) — ƯỚC LƯỢNG
# theo hình học, chưa đo trên người thật.
HIP_HYPEREXTENDED_THRESHOLD = 165.0
# Góc thô khi ở vị trí bắt đầu (chân đứng dưới thân, hông mới gập nhẹ).
HIP_FLEXED_THRESHOLD = 130.0


class KickbackAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật glute kickback (duỗi hông ra sau) và trả feedback tiếng Việt."""

    SUPPORTS_SINGLE_SIDE = True

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
        single_side: bool = True,
    ) -> None:
        t = thresholds or {}
        hyperextended_raw = t.get("hip_hyperextended", HIP_HYPEREXTENDED_THRESHOLD)
        flexed_raw = t.get("hip_flexed", HIP_FLEXED_THRESHOLD)
        super().__init__(
            rep_counter
            or RepCounter(
                # Góc bù: xem chú thích BẪY GÓC ở đầu file.
                down_threshold=180.0 - hyperextended_raw,
                up_threshold=180.0 - flexed_raw,
            ),
            thresholds,
        )
        self._single_side = single_side

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

        left_compensated = 180.0 - left_hip_angle if left_hip_angle is not None else None
        right_compensated = 180.0 - right_hip_angle if right_hip_angle is not None else None
        compensated_angle = (
            active_side(left_compensated, right_compensated)
            if self._single_side
            else avg(left_compensated, right_compensated)
        )

        phase = self.rep_counter.phase.value
        if compensated_angle is not None:
            self.rep_counter.update(compensated_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa duỗi hông đủ ra sau — đá chân về sau và siết mông ở đỉnh mỗi rep.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_hip=left_hip_angle, right_hip=right_hip_angle),
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
