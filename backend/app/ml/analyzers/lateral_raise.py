"""Phân tích kỹ thuật Raise (nâng tay dạng vai): độ nâng cao, lệch hai bên.

Gộp chung Lateral Raise / Front Raise / Rear Delt Fly vào MỘT analyzer vì cả
ba cùng một cơ chế góc dù mặt phẳng chuyển động khác nhau (sang ngang / ra
trước / ra sau-lên): khớp chính di chuyển là VAI, không phải khuỷu tay như
curl/row — khuỷu tay giữ gần như cố định suốt rep.

KHÔNG dùng cho Chest Fly / Pec Fly: đó là chiều ngược lại (khép hai tay lại
MỚI là đỉnh rep) — xem `ChestFlyAnalyzer` riêng, và chú thích `ELEVATION`
bên dưới về lý do hai bài "cùng họ raise/fly" lại cần công thức góc khác nhau.

BẪY GÓC — ĐỌC TRƯỚC KHI SỬA
----------------------------
Góc hông-vai-khuỷu tay THÔ (`calculate_angle_3d(hip, shoulder, elbow)`) NHỎ
lúc tay xuôi theo thân (~15°) và LỚN lúc tay nâng ngang vai (~85°) — ngược
hẳn với mọi analyzer khác trong file này (squat/row/curl/deadlift... đều có
vị trí NGHỈ ứng với góc LỚN, vị trí làm việc ứng với góc NHỎ). `RepCounter`
mặc định bắt đầu ở `Phase.TOP`, tức giả định trạng thái nghỉ ban đầu có góc
**lớn hơn** `up_threshold` — nếu nạp thẳng góc thô vào (nghỉ = góc NHỎ, dưới
cả `down_threshold`), `RepCounter` sẽ hiểu nhầm là người tập vừa chạm đáy
ngay ở FRAME ĐẦU TIÊN, trước khi họ làm gì cả, và đếm nhầm 1 rep khống.

Vì vậy dùng GÓC BÙ `180 - raw` để đếm rep (biến `ELEVATION_*`): bù xong thì
nghỉ = góc lớn (~165°, khớp đúng giả định TOP mặc định), nâng hết cỡ = góc
nhỏ (~95-100°) — cùng chiều với mọi analyzer khác. `key_angles` trả về vẫn
là góc thô (`left_shoulder`/`right_shoulder`) vì đó là con số người đọc code
sau này mong đợi ("90° = tay ngang vai"), không phải góc bù chỉ có ý nghĩa
nội bộ cho `RepCounter`.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc THÔ (hông-vai-khuỷu tay) coi là "đã nâng đủ cao" — tay lên tới ít nhất
# ngang vai. ƯỚC LƯỢNG theo hình học, chưa đo trên người thật (cùng tình
# trạng với ngưỡng seed ban đầu của squat/lunge/deadlift, xem CHANGELOG
# 01/09/2026) — cần hiệu chỉnh qua `ExercisePostureRules` sau khi có người
# test thật.
SHOULDER_RAISED_RAW = 80.0
# Góc THÔ coi là "đang ở vị trí nghỉ" — tay xuôi theo thân.
SHOULDER_REST_RAW = 25.0
# Chênh lệch góc hai tay quá mức này là nâng lệch bên (đo trên góc thô, việc
# bù 180° không đổi trị tuyệt đối của hiệu số).
SHOULDER_ASYMMETRY_THRESHOLD = 25.0


class LateralRaiseAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật raise (nâng tay dạng vai) và trả feedback tiếng Việt."""

    SUPPORTS_SINGLE_SIDE = True

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
        single_side: bool = False,
    ) -> None:
        t = thresholds or {}
        raised_raw = t.get("shoulder_raised", SHOULDER_RAISED_RAW)
        rest_raw = t.get("shoulder_rest", SHOULDER_REST_RAW)
        super().__init__(
            rep_counter
            or RepCounter(
                # Góc bù: xem chú thích BẪY GÓC ở đầu file.
                down_threshold=180.0 - raised_raw,
                up_threshold=180.0 - rest_raw,
            ),
            thresholds,
        )
        # Bài một tay (vd Band Single Arm Lateral Raise) — xem docstring tham
        # số cùng tên ở RowAnalyzer. active_side() phải nhận GÓC ĐÃ BÙ (xem
        # analyze() bên dưới), không phải góc thô — góc thô của bài này quy
        # ước ngược (nghỉ = nhỏ, làm việc = lớn), min() trên góc thô sẽ chọn
        # nhầm đúng bên đang nghỉ.
        self._single_side = single_side

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

        # Bù 180° TỪNG BÊN trước rồi mới gộp — về mặt toán học tương đương
        # avg(180-left, 180-right) == 180-avg(left, right) khi không phải
        # single_side (phép bù tuyến tính giao hoán với trung bình), nên
        # hành vi hai tay giữ nguyên y hệt trước; nhưng active_side() (single
        # tay) BẮT BUỘC nhận góc đã bù mới chọn đúng bên đang làm việc.
        left_compensated = 180.0 - left_shoulder_angle if left_shoulder_angle is not None else None
        right_compensated = 180.0 - right_shoulder_angle if right_shoulder_angle is not None else None
        compensated_angle = (
            active_side(left_compensated, right_compensated)
            if self._single_side
            else avg(left_compensated, right_compensated)
        )

        phase = self.rep_counter.phase.value
        if compensated_angle is not None:
            self.rep_counter.update(compensated_angle)
            phase = self.rep_counter.phase.value

            # Đỉnh rep (tay nâng cao nhất) ứng với góc BÙ nhỏ nhất — cùng cơ
            # chế `shallow_reversal` của squat/row/curl: nhắc đúng lúc đảo
            # chiều hạ tay xuống mà chưa nâng đủ cao, không lặp lại mọi frame
            # đang hạ (xem CHANGELOG 01/09/2026 về lỗi suy điều kiện từ `phase`).
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa nâng tay đủ cao — nâng lên ít nhất ngang vai.")

        if (
            not self._single_side
            and left_shoulder_angle is not None
            and right_shoulder_angle is not None
        ):
            limit = self.threshold("shoulder_asymmetry", SHOULDER_ASYMMETRY_THRESHOLD)
            if abs(left_shoulder_angle - right_shoulder_angle) > limit:
                errors.append("Hai tay nâng không đều — giữ tốc độ và độ cao hai bên bằng nhau.")

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
