"""Phân tích kỹ thuật Face Pull: độ kéo dây/band về mặt, lệch hai bên.

Cùng bộ ba khớp (vai-khuỷu tay-cổ tay) và cùng chiều ngưỡng với
`RowAnalyzer` (duỗi thẳng ở vị trí bắt đầu, gập khuỷu tay ở đỉnh rep) —
KHÔNG dùng chung class vì lời nhắc kỹ thuật khác nhau: face pull kéo dây
NGANG VAI, khuỷu tay mở rộng sang hai bên và ra sau (không phải kéo về
hông/bụng như row), và không có khái niệm "lưng cong" cần kiểm vì face pull
thường đứng/ngồi thẳng người, không cúi. Đây đúng kiểu lỗi CLAUDE.md đã cảnh
báo: kỹ thuật đo giống nhau không có nghĩa lời nhắc giống nhau (xem
`tricep_extension.py`, `pullover.py` cho các ví dụ tương tự).
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là đã kéo hết (dây/band gần chạm mặt).
ELBOW_CONTRACTED_THRESHOLD = 70.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã về vị trí bắt đầu (tay gần thẳng).
ELBOW_EXTENDED_THRESHOLD = 155.0
# Chênh lệch góc hai tay quá mức này là kéo lệch bên.
ELBOW_ASYMMETRY_THRESHOLD = 25.0


class FacePullAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật face pull (kéo dây về mặt) và trả feedback tiếng Việt."""

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

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa kéo hết — kéo dây/band về gần mặt hơn ở đỉnh mỗi rep.")

        if left_elbow_angle is not None and right_elbow_angle is not None:
            limit = self.threshold("elbow_asymmetry", ELBOW_ASYMMETRY_THRESHOLD)
            if abs(left_elbow_angle - right_elbow_angle) > limit:
                errors.append("Hai tay kéo không đều — giữ tốc độ và độ kéo hai bên bằng nhau.")

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
