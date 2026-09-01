"""Phân tích kỹ thuật Lunge: độ sâu gối trước, gối trước không vượt mũi chân."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import is_visible, visible_points
from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

KNEE_DEPTH_THRESHOLD = 100.0     # Gối trước phải gập ≤ ngưỡng này mới đủ sâu
KNEE_OVERSHOOT_RATIO = 0.05      # Gối trước không được vượt qua mũi chân quá 5% chiều rộng frame
BACK_STRAIGHT_MIN = 150.0        # Góc vai-hông-gối phải ≥ ngưỡng này (thân thẳng, không cúi)


class LungeAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật lunge và trả feedback tiếng Việt.

    Lunge là động tác một bên chân — trong hai chân, chân nào đang gập sâu
    hơn (góc gối nhỏ hơn) chính là "chân trước" đang chịu lực ở thời điểm
    đó, nên dùng min() của hai góc gối thay vì trung bình như squat."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        super().__init__(
            rep_counter
            or RepCounter(
                down_threshold=t.get("knee_depth", KNEE_DEPTH_THRESHOLD),
                up_threshold=t.get("stand_up_min", 160.0),
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
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]
        left_foot = keypoints[31]
        right_foot = keypoints[32]

        left_knee_angle: float | None = None
        right_knee_angle: float | None = None

        if is_visible(left_hip, left_knee, left_ankle):
            left_knee_angle = calculate_angle_3d(left_hip, left_knee, left_ankle)
        if is_visible(right_hip, right_knee, right_ankle):
            right_knee_angle = calculate_angle_3d(right_hip, right_knee, right_ankle)

        front_knee_angle: float | None = None
        if left_knee_angle is not None and right_knee_angle is not None:
            front_knee_angle = min(left_knee_angle, right_knee_angle)
        elif left_knee_angle is not None:
            front_knee_angle = left_knee_angle
        elif right_knee_angle is not None:
            front_knee_angle = right_knee_angle

        phase = self.rep_counter.phase.value
        if front_knee_angle is not None:
            self.rep_counter.update(front_knee_angle)
            phase = self.rep_counter.phase.value

            # Chấm độ sâu tại ĐÚNG LÚC đảo chiều đi lên, không phải mọi frame
            # đang đi lên. Điều kiện cũ `phase in ("bottom","going_up") and góc >
            # ngưỡng` không bao giờ đúng được: ở BOTTOM góc luôn ≤ ngưỡng (nếu
            # không đã chuyển phase), còn ở GOING_UP góc đương nhiên lớn hơn —
            # đó là định nghĩa của việc đi lên. Kết quả là một rep hoàn hảo vẫn
            # bị báo lỗi suốt lúc đứng lên, TTS đọc oan và điểm chính xác tụt
            # (đo được: rep squat chuẩn chỉ đạt 64,5%).
            if self.rep_counter.shallow_reversal:
                errors.append("Chùng chân chưa đủ sâu — hạ thấp hông thêm cho đùi trước song song sàn.")

        if is_visible(left_knee, left_foot) and left_knee_angle == front_knee_angle:
            if left_knee.x > left_foot.x + KNEE_OVERSHOOT_RATIO:
                errors.append("Gối trước vượt quá mũi chân — lùi chân sau ra xa hơn.")
        if is_visible(right_knee, right_foot) and right_knee_angle == front_knee_angle:
            if right_knee.x < right_foot.x - KNEE_OVERSHOOT_RATIO:
                errors.append("Gối trước vượt quá mũi chân — lùi chân sau ra xa hơn.")

        back_angle: float | None = None
        left_back_ok = is_visible(left_shoulder, left_hip, left_knee)
        right_back_ok = is_visible(right_shoulder, right_hip, right_knee)
        if left_back_ok:
            back_angle = calculate_angle(left_shoulder, left_hip, left_knee)
        elif right_back_ok:
            back_angle = calculate_angle(right_shoulder, right_hip, right_knee)

        if back_angle is not None and back_angle < self.threshold("back_straight_min", BACK_STRAIGHT_MIN):
            errors.append(f"Thân trên cúi quá (góc {back_angle:.0f}°) — giữ lưng thẳng, ngực hướng trước.")

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(
                left_knee=left_knee_angle,
                right_knee=right_knee_angle,
                left_hip=calculate_angle(left_shoulder, left_hip, left_knee) if left_back_ok else None,
                right_hip=calculate_angle(right_shoulder, right_hip, right_knee) if right_back_ok else None,
                back_angle=back_angle,
            ),
            phase=phase,
            keypoints=visible_points({
                "left_shoulder": left_shoulder,
                "right_shoulder": right_shoulder,
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_knee": left_knee,
                "right_knee": right_knee,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
