"""Phân tích kỹ thuật Crunch/Sit-up/Knee Raise: độ gập bụng.

Cùng bộ ba khớp (vai-hông-gối) với `DeadliftAnalyzer`/`HipThrustAnalyzer`,
nhưng đo GÓC GẬP BỤNG chứ không phải gập-duỗi hông đứng — gộp chung hai
nhóm động tác tưởng khác nhau vì cùng làm giảm góc vai-hông-gối theo cùng
một cách:

- Crunch/Sit-up (nằm, chân cố định): THÂN cong lên về phía gối.
- Hanging/Captains Chair Knee Raise (treo/tựa, thân cố định): GỐI kéo lên
  về phía thân.

Công thức góc 3 điểm không phân biệt đầu nào di chuyển — cả hai đều đọc ra
góc vai-hông-gối giảm dần, nên dùng chung MỘT analyzer, giống cách
`BenchPressAnalyzer` không phân biệt tư thế nằm/đứng.

CỐ TÌNH KHÔNG kiểm "lệch hai bên": gập bụng là chuyển động cột sống đối
xứng theo bản chất, không giống tay/chân có thể lệch bên do bù lực — chênh
lệch nhỏ giữa hai bên vai-hông-gối thường chỉ do góc camera/pose estimation,
không phải lỗi kỹ thuật đáng nhắc.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc vai-hông-gối khi đã gập bụng/kéo gối hết cỡ (đỉnh rep) — ƯỚC LƯỢNG
# theo hình học, chưa đo trên người thật, cần hiệu chỉnh qua
# `ExercisePostureRules`.
HIP_CONTRACTED_THRESHOLD = 110.0
# Góc khi thân/chân duỗi thẳng (vị trí nghỉ/bắt đầu).
HIP_EXTENDED_THRESHOLD = 165.0


class CrunchAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật crunch/sit-up/knee raise và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("hip_contracted", HIP_CONTRACTED_THRESHOLD),
                up_threshold=t.get("hip_extended", HIP_EXTENDED_THRESHOLD),
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

        hip_angle = avg(left_hip_angle, right_hip_angle)

        phase = self.rep_counter.phase.value
        if hip_angle is not None:
            self.rep_counter.update(hip_angle)
            phase = self.rep_counter.phase.value

            # Đỉnh rep là góc NHỎ nhất (gập bụng/kéo gối hết cỡ) — cùng cơ
            # chế shallow_reversal của curl/row (CHANGELOG 01/09/2026).
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa gập bụng đủ — kéo thân/gối gần nhau hơn ở đỉnh mỗi rep.")

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
