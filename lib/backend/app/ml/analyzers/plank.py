"""Phân tích kỹ thuật Plank: giữ thân thẳng hàng vai-hông-mắt cá.

Khác với các bài đếm rep — Plank là bài giữ tư thế (hold), nên analyzer này
không dùng RepCounter để đếm chu kỳ lên/xuống. `rep_count` luôn = 0 và
`phase` luôn = "top" (đang giữ); toàn bộ giá trị nằm ở `errors`, cập nhật
liên tục theo từng frame để nhắc chỉnh tư thế ngay khi lệch."""

from app.ml.angle_utils import calculate_angle
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import is_visible, visible_points
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Góc vai-hông-mắt cá phải nằm trong khoảng này mới coi là thân thẳng hàng.
# 180° là một đường thẳng tuyệt đối — thực tế cho phép lệch nhẹ.
STRAIGHT_BODY_MIN = 160.0
# Dưới ngưỡng này rõ ràng là hông đang võng xuống (sai phổ biến nhất).
HIP_SAG_THRESHOLD = 150.0


class PlankAnalyzer(ExerciseAnalyzer):
    """Phân tích tư thế plank theo từng frame — không đếm rep."""

    def __init__(self, rep_counter: RepCounter | None = None) -> None:
        # RepCounter không dùng tới (không có chu kỳ lên/xuống) nhưng base
        # class yêu cầu instance — tạo cho đủ interface, không gọi .update().
        super().__init__(rep_counter or RepCounter())

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]

        left_line_angle: float | None = None
        right_line_angle: float | None = None

        if is_visible(left_shoulder, left_hip, left_ankle):
            left_line_angle = calculate_angle(left_shoulder, left_hip, left_ankle)
        if is_visible(right_shoulder, right_hip, right_ankle):
            right_line_angle = calculate_angle(right_shoulder, right_hip, right_ankle)

        body_line_angle = left_line_angle if left_line_angle is not None else right_line_angle

        if body_line_angle is not None:
            if body_line_angle < HIP_SAG_THRESHOLD:
                errors.append(
                    f"Hông đang võng xuống (góc {body_line_angle:.0f}°) — siết bụng, nâng hông lên "
                    "cho thẳng hàng với vai và chân."
                )
            elif body_line_angle < STRAIGHT_BODY_MIN:
                errors.append("Hông hơi cao hơn mức thẳng hàng — hạ hông xuống một chút.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(
                left_hip=left_line_angle,
                right_hip=right_line_angle,
                back_angle=body_line_angle,
            ),
            phase=self.rep_counter.phase.value,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
