"""Phân tích kỹ thuật Hip Abduction: độ dạng chân sang ngang, luôn một chân.

Cùng bộ ba khớp (vai-hông-gối) với `DeadliftAnalyzer`/`HipThrustAnalyzer`,
nhưng đo chuyển động chân DẠNG SANG NGANG (mặt phẳng trán) thay vì gập-duỗi
hông (mặt phẳng đứng dọc). Đứng thẳng/chân khép (nghỉ) thì hông-gối gần như
thẳng hàng với vai — góc LỚN (~170-180°); dạng chân ra ngoài thì gối lệch xa
khỏi đường thẳng đó — góc NHỎ dần. Cùng chiều `RowAnalyzer`/`CurlAnalyzer`
(nghỉ = lớn, làm việc = nhỏ), dùng `calculate_angle_3d` nên không phụ thuộc
góc camera chính xác (đứng nghiêng hay trực diện đều đọc được, khác giả
định nhìn nghiêng CHẶT của squat/lunge — squat/lunge còn kiểm thêm gối vượt
mũi chân theo toạ độ x 2D, ở đây thì không).

LUÔN single_side=True: bài này về bản chất luôn tập TỪNG CHÂN một (đứng trụ
một chân, dạng chân kia ra ngoài) — không có biến thể hai chân đồng thời
trong thư viện. Chân trụ đứng yên giữ nguyên góc LỚN suốt bài (không có vị
trí "nghỉ giữa hai lần" nào khác góc đứng thẳng), an toàn cho `active_side()`
— khác bẫy đã né ở `CalfRaiseAnalyzer` (xem CHANGELOG 13/09/2026).

CỐ TÌNH CHƯA gộp Hip Adduction (Machine Hip Adduction) vào đây: đó là bài
HAI CHÂN đồng thời (khép hai chân đang mở vào giữa trên máy), ngưỡng đi
chiều ngược lại và không phải single_side — cần thiết kế riêng, để dành.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc vai-hông-gối khi đã dạng chân hết cỡ (đỉnh rep) — ƯỚC LƯỢNG theo hình
# học, chưa đo trên người thật, cần hiệu chỉnh qua `ExercisePostureRules`.
HIP_ABDUCTED_THRESHOLD = 140.0
# Góc khi đứng thẳng/chân khép (vị trí nghỉ/bắt đầu).
HIP_ADDUCTED_THRESHOLD = 172.0


class HipAbductionAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật hip abduction (dạng chân sang ngang) và trả feedback tiếng Việt."""

    SUPPORTS_SINGLE_SIDE = True

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
        single_side: bool = True,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("hip_abducted", HIP_ABDUCTED_THRESHOLD),
                up_threshold=t.get("hip_adducted", HIP_ADDUCTED_THRESHOLD),
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

        hip_angle = (
            active_side(left_hip_angle, right_hip_angle)
            if self._single_side
            else avg(left_hip_angle, right_hip_angle)
        )

        phase = self.rep_counter.phase.value
        if hip_angle is not None:
            self.rep_counter.update(hip_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa dạng chân đủ xa — đưa chân ra ngoài nhiều hơn ở đỉnh mỗi rep.")

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
