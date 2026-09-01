"""Phân tích kỹ thuật Row (kéo tạ về thân): độ co khuỷu tay, lưng thẳng."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là đã kéo hết (tạ chạm gần thân).
ELBOW_CONTRACTED_THRESHOLD = 70.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã về vị trí bắt đầu (tay thẳng).
ELBOW_EXTENDED_THRESHOLD = 150.0
# Góc hông-vai-gối < ngưỡng này nghĩa là lưng đang cong khi cúi kéo tạ.
BACK_STRAIGHT_MIN = 100.0


class RowAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật row (kéo tạ) và trả feedback tiếng Việt."""

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
        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]

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

            # Chấm độ sâu tại ĐÚNG LÚC đảo chiều đi lên, không phải mọi frame
            # đang đi lên. Điều kiện cũ `phase in ("bottom","going_up") and góc >
            # ngưỡng` không bao giờ đúng được: ở BOTTOM góc luôn ≤ ngưỡng (nếu
            # không đã chuyển phase), còn ở GOING_UP góc đương nhiên lớn hơn —
            # đó là định nghĩa của việc đi lên. Kết quả là một rep hoàn hảo vẫn
            # bị báo lỗi suốt lúc đứng lên, TTS đọc oan và điểm chính xác tụt
            # (đo được: rep squat chuẩn chỉ đạt 64,5%).
            if self.rep_counter.shallow_reversal:
                errors.append("Kéo tạ chưa hết — kéo khuỷu tay sát về phía thân người hơn.")

        back_angle: float | None = None
        left_back_ok = is_visible(left_shoulder, left_hip, left_knee)
        right_back_ok = is_visible(right_shoulder, right_hip, right_knee)
        if left_back_ok:
            back_angle = calculate_angle(left_shoulder, left_hip, left_knee)
        elif right_back_ok:
            back_angle = calculate_angle(right_shoulder, right_hip, right_knee)

        if back_angle is not None and back_angle < self.threshold("back_straight_min", BACK_STRAIGHT_MIN):
            errors.append(f"Lưng bị cong (góc {back_angle:.0f}°) — giữ lưng thẳng, không gù vai.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(
                left_elbow=left_elbow_angle,
                right_elbow=right_elbow_angle,
                left_hip=calculate_angle(left_shoulder, left_hip, left_knee) if left_back_ok else None,
                right_hip=calculate_angle(right_shoulder, right_hip, right_knee) if right_back_ok else None,
                back_angle=back_angle,
            ),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_elbow": left_elbow,
                "right_elbow": right_elbow,
                "left_wrist": left_wrist,
                "right_wrist": right_wrist,
                "left_hip": left_hip,
                "right_hip": right_hip,
            }),
        )
