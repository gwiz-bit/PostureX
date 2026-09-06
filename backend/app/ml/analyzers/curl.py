"""Phân tích kỹ thuật Curl (gập khuỷu tay co bắp tay trước): độ co, lệch hai bên."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là đã curl hết (tạ lên gần vai).
ELBOW_CONTRACTED_THRESHOLD = 50.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã hạ tạ về vị trí bắt đầu (tay gần thẳng).
ELBOW_EXTENDED_THRESHOLD = 160.0
# Chênh lệch góc hai tay quá mức này là curl lệch bên (một tay bù lực cho tay kia).
ELBOW_ASYMMETRY_THRESHOLD = 25.0


class CurlAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật curl (gập khuỷu tay) và trả feedback tiếng Việt.

    Cùng cấu trúc góc khuỷu tay với `RowAnalyzer` (`down_threshold` = co hết,
    `up_threshold` = duỗi hết) — khác ở chỗ curl không cúi người nên không có
    ngưỡng lưng thẳng, và mọi biến thể curl trong thư viện dùng chung file
    này (Barbell/Dumbbell/Cable/Ez Bar/Hammer/Preacher...), chỉ khác thiết bị
    cầm chứ không khác cơ chế góc khớp.
    """

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("elbow_contracted", ELBOW_CONTRACTED_THRESHOLD),
                up_threshold=t.get("elbow_extended", ELBOW_EXTENDED_THRESHOLD),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_shoulder = keypoints[11]
        right_shoulder = keypoints[12]
        left_elbow = keypoints[13]
        right_elbow = keypoints[14]
        left_wrist = keypoints[15]
        right_wrist = keypoints[16]

        left_elbow_angle: float | None = None
        right_elbow_angle: float | None = None

        if is_visible(left_shoulder, left_elbow, left_wrist):
            left_elbow_angle = calculate_angle_3d(left_shoulder, left_elbow, left_wrist)
        if is_visible(right_shoulder, right_elbow, right_wrist):
            right_elbow_angle = calculate_angle_3d(right_shoulder, right_elbow, right_wrist)

        elbow_angle = avg(left_elbow_angle, right_elbow_angle)

        phase = self.rep_counter.phase.value
        if elbow_angle is not None:
            self.rep_counter.update(elbow_angle)
            phase = self.rep_counter.phase.value

            # Chấm độ co tại ĐÚNG LÚC đảo chiều đi xuống (bắt đầu hạ tạ), không
            # phải mọi frame đang hạ — cùng lỗi kinh điển đã sửa ở squat/row/
            # bench press (xem CHANGELOG 01/09/2026): điều kiện suy từ `phase`
            # tự mâu thuẫn, nên đọc thẳng cờ `shallow_reversal` của RepCounter.
            if self.rep_counter.shallow_reversal:
                errors.append("Chưa curl đủ cao — gập khuỷu tay nhiều hơn để tạ lên gần vai.")

        if left_elbow_angle is not None and right_elbow_angle is not None:
            limit = self.threshold("elbow_asymmetry", ELBOW_ASYMMETRY_THRESHOLD)
            if abs(left_elbow_angle - right_elbow_angle) > limit:
                errors.append("Hai tay curl không đều — giữ tốc độ và độ cao hai bên bằng nhau.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_elbow=left_elbow_angle, right_elbow=right_elbow_angle),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_elbow": left_elbow,
                "right_elbow": right_elbow,
                "left_wrist": left_wrist,
                "right_wrist": right_wrist,
            }),
        )
