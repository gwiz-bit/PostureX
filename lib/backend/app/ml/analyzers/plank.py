"""Phân tích kỹ thuật Plank: giữ thân thẳng hàng vai-hông-mắt cá.

Khác với các bài đếm rep — Plank là bài giữ tư thế (hold), nên analyzer này
không dùng RepCounter để đếm chu kỳ lên/xuống. `rep_count` luôn = 0; toàn bộ
giá trị nằm ở `errors`, cập nhật liên tục theo từng frame để nhắc chỉnh tư
thế ngay khi lệch.

`phase` được dùng để báo "đã thực sự vào tư thế plank hay chưa" — KHÔNG phải
enum lên/xuống như các bài đếm rep: "top" = chưa vào tư thế (đứng bình
thường/đang chuẩn bị), "holding" = đã nằm plank thật. Đây là điểm mấu chốt:
góc vai-hông-mắt cá của một người ĐỨNG THẲNG bình thường cũng ~180° — GIỐNG
HỆT một plank đúng chuẩn, vì công thức tính góc 3 điểm không phân biệt được
hướng cơ thể trong khung hình (đứng dọc hay nằm ngang). Nếu chỉ xét mỗi góc
đó, đứng yên trước camera sẽ bị chấm "đúng kỹ thuật" dù chưa hề vào plank —
đây chính là lý do độ chính xác hiển thị sai (gần 100%) khi user chưa tập
gì. Client (analyze_session_screen.dart) chỉ tính điểm chính xác cho các
frame có `phase != "top"`, nên phải xác định đúng lúc nào user THỰC SỰ đang
giữ plank trước khi tính điểm cho khung hình đó."""

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
# Thân người trải theo chiều ngang khung hình (x) phải lớn hơn chiều dọc (y)
# ít nhất tỉ lệ này mới coi là đang nằm plank (không phải đứng thẳng) — với
# tư thế đứng bình thường, vai-hông-mắt cá gần như thẳng cột theo trục y nên
# tỉ lệ ngang/dọc rất nhỏ; nằm plank nhìn ngang thì ngược lại.
HORIZONTAL_POSTURE_RATIO = 1.2


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

        shoulder = left_shoulder if left_line_angle is not None else right_shoulder
        ankle = left_ankle if left_line_angle is not None else right_ankle
        in_plank_position = body_line_angle is not None and _is_horizontal(shoulder, ankle)

        if not in_plank_position:
            # Chưa nằm xuống vào tư thế plank (đang đứng/chuẩn bị) — không
            # chấm lỗi tư thế (không có gì để chấm) và báo phase="top" để
            # client không tính khung hình này vào độ chính xác.
            return FrameAnalysisResult(
                rep_count=0,
                errors=[],
                correct=True,
                key_angles=KeyAngles(
                    left_hip=left_line_angle, right_hip=right_line_angle, back_angle=body_line_angle
                ),
                phase="top",
                keypoints=visible_points({
                    "left_shoulder": left_shoulder,
                    "right_shoulder": right_shoulder,
                    "left_hip": left_hip,
                    "right_hip": right_hip,
                    "left_ankle": left_ankle,
                    "right_ankle": right_ankle,
                }),
            )

        if body_line_angle < HIP_SAG_THRESHOLD:
            errors.append(
                f"Hông đang võng xuống (góc {body_line_angle:.0f}°) — siết bụng, nâng hông lên "
                "cho thẳng hàng với vai và chân."
            )
        elif body_line_angle < STRAIGHT_BODY_MIN:
            errors.append("Hông hơi cao hơn mức thẳng hàng — hạ hông xuống một chút.")

        return FrameAnalysisResult(
            rep_count=0,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(
                left_hip=left_line_angle,
                right_hip=right_line_angle,
                back_angle=body_line_angle,
            ),
            phase="holding",
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )


def _is_horizontal(shoulder: Keypoint, ankle: Keypoint) -> bool:
    """True nếu thân người trải ngang khung hình (đang nằm plank) thay vì
    đứng thẳng — so sánh khoảng cách ngang (x) và dọc (y) giữa vai và mắt cá."""
    horizontal_span = abs(shoulder.x - ankle.x)
    vertical_span = abs(shoulder.y - ankle.y) + 1e-6
    return horizontal_span / vertical_span >= HORIZONTAL_POSTURE_RATIO
