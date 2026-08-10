"""Phân tích kỹ thuật Bench Press: độ hạ tạ (khuỷu tay gập) và khoá tay đủ ở đỉnh."""

from app.ml.angle_utils import calculate_angle_3d
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là hạ tạ đủ sâu (tạ gần chạm ngực).
ELBOW_DOWN_THRESHOLD = 95.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã khoá tay hoàn toàn.
ELBOW_LOCKOUT_THRESHOLD = 160.0
# Chênh lệch góc hai tay quá mức này nghĩa là đẩy tạ lệch bên.
ELBOW_ASYMMETRY_THRESHOLD = 25.0


class BenchPressAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật bench press (đẩy ngực) và trả feedback tiếng Việt.

    Dùng góc khuỷu tay làm chỉ số chính — công thức này không phụ thuộc tư
    thế nằm hay đứng, nên vẫn hoạt động dù camera nhìn người dùng từ góc
    nào (miễn thấy rõ vai-khuỷu-cổ tay)."""

    def __init__(self, rep_counter: RepCounter | None = None) -> None:
        super().__init__(
            rep_counter
            or RepCounter(down_threshold=ELBOW_DOWN_THRESHOLD, up_threshold=ELBOW_LOCKOUT_THRESHOLD)
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

            if phase in ("bottom", "going_up") and elbow_angle > ELBOW_DOWN_THRESHOLD:
                errors.append("Hạ tạ chưa đủ sâu — hạ khuỷu tay gập thêm cho tạ gần chạm ngực.")

        if left_elbow_angle is not None and right_elbow_angle is not None:
            if abs(left_elbow_angle - right_elbow_angle) > ELBOW_ASYMMETRY_THRESHOLD:
                errors.append("Hai tay đẩy tạ không đều — giữ tốc độ và độ cao hai bên bằng nhau.")

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
