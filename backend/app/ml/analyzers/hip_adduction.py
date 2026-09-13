"""Phân tích kỹ thuật Hip Adduction (khép chân vào trong): hai chân đồng thời.

Cùng bộ ba khớp (vai-hông-gối) và cùng công thức `calculate_angle_3d` với
`HipAbductionAnalyzer`, nhưng NGƯỢC chiều bài tập lẫn ngược chiều rep — xem
comment "CỐ TÌNH CHƯA gộp" trong `hip_abduction.py`:

- Hip Abduction: NGHỈ = chân khép (góc THÔ LỚN, ~172°), LÀM VIỆC = dạng chân
  ra ngoài (góc THÔ NHỎ, ~140°).
- Hip Adduction: máy giữ hai chân banh MỞ sẵn bằng đệm (NGHỈ = góc THÔ NHỎ,
  ~140°, giống trạng thái "làm việc" của Hip Abduction), người tập chủ động ép
  KHÉP hai chân lại (LÀM VIỆC/đỉnh rep = góc THÔ LỚN, ~172°, giống trạng thái
  "nghỉ" của Hip Abduction).

BẪY GÓC — giống hệt LateralRaiseAnalyzer (đọc docstring class đó trước khi
sửa): `RepCounter` mặc định giả định trạng thái nghỉ ban đầu có góc LỚN hơn
`up_threshold`. Ở Hip Adduction, nghỉ lại là góc NHỎ (chân đang mở) — nạp
thẳng góc thô sẽ khiến `RepCounter` tưởng vừa chạm đáy ngay ở frame đầu tiên.
Dùng góc bù `180 - raw` để đếm rep, y hệt cách LateralRaiseAnalyzer đã làm:
bù xong thì nghỉ (mở, raw nhỏ) thành góc bù LỚN, khép hết (raw lớn) thành góc
bù NHỎ — đúng chiều RepCounter mong đợi. `key_angles` vẫn trả góc thô.

LUÔN hai chân đồng thời (không single_side): máy ép cả hai chân cùng lúc,
khác Hip Abduction luôn tập từng chân một trên máy đứng.

Tái dùng đúng khoá `hip_abducted`/`hip_adducted` đã có của `HipAbductionAnalyzer`
— cùng Ý NGHĨA VẬT LÝ (ngưỡng góc thô ở trạng thái dạng/khép chân), chỉ khác
analyzer nào dùng chúng làm down/up threshold cho `RepCounter` (và có bù 180°
hay không). `ExercisePostureRules` phân biệt hai bài theo `exercise_id`, nên
ghi đè ngưỡng riêng cho "Machine Hip Abduction" không ảnh hưởng "Machine Hip
Adduction" dù cùng tên khoá.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Cùng giá trị ước lượng với HipAbductionAnalyzer — cùng cơ chế góc thô, chỉ
# khác chiều rep. ƯỚC LƯỢNG theo hình học, chưa đo trên người thật.
HIP_ABDUCTED_THRESHOLD = 140.0   # Góc thô khi chân đang mở trên máy (nghỉ/bắt đầu)
HIP_ADDUCTED_THRESHOLD = 172.0   # Góc thô khi đã khép chân hết cỡ (đỉnh rep)


class HipAdductionAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật hip adduction (khép chân vào trong) và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        abducted_raw = t.get("hip_abducted", HIP_ABDUCTED_THRESHOLD)
        adducted_raw = t.get("hip_adducted", HIP_ADDUCTED_THRESHOLD)
        super().__init__(
            rep_counter
            or RepCounter(
                # Góc bù: xem chú thích BẪY GÓC ở đầu file.
                down_threshold=180.0 - adducted_raw,
                up_threshold=180.0 - abducted_raw,
            ),
            thresholds,
        )

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
        compensated_angle = avg(left_compensated, right_compensated)

        phase = self.rep_counter.phase.value
        if compensated_angle is not None:
            self.rep_counter.update(compensated_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa khép chân đủ vào trong — ép hai gối lại gần nhau hơn ở đỉnh mỗi rep.")

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
