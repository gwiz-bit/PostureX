"""Phân tích kỹ thuật squat: độ sâu, gối vượt mũi chân, lưng thẳng."""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import avg as _avg
from app.ml.analyzers.common import is_visible as _visible
from app.ml.analyzers.common import visible_points as _visible_points
from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Ngưỡng góc (độ)
KNEE_DEPTH_THRESHOLD = 95.0      # Gối phải gập ≤ ngưỡng này mới đủ sâu
KNEE_OVERSHOOT_RATIO = 0.05      # Gối không được vượt qua mũi chân quá 5% chiều rộng frame
BACK_STRAIGHT_MIN = 150.0        # Góc hông-vai-cổ phải ≥ ngưỡng này (lưng thẳng)


class SquatAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật squat và trả feedback tiếng Việt."""

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        t = thresholds or {}
        # up_threshold 155° thay vì 160° — thực tế nhiều người không duỗi thẳng
        # hết gối khi đứng, 155° đã đủ để tính là đứng thẳng mà không làm mất
        # độ chính xác của bài tập.
        super().__init__(rep_counter or RepCounter(
                down_threshold=t.get("knee_depth", KNEE_DEPTH_THRESHOLD),
                up_threshold=t.get("stand_up_min", 155.0),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        """Phân tích một frame squat, cập nhật đếm rep, trả kết quả."""
        errors: list[str] = []

        # --- Lấy các khớp cần thiết ---
        left_shoulder  = keypoints[11]
        right_shoulder = keypoints[12]
        left_hip       = keypoints[23]
        right_hip      = keypoints[24]
        left_knee      = keypoints[25]
        right_knee     = keypoints[26]
        left_ankle     = keypoints[27]
        right_ankle    = keypoints[28]
        left_foot      = keypoints[31]   # left_foot_index
        right_foot     = keypoints[32]   # right_foot_index

        # --- Tính góc gối ---
        # Dùng góc 3D (x, y, z) thay vì chỉ 2D: khi người dùng quay thẳng
        # mặt vào camera, gối gập chủ yếu theo chiều sâu (z) chứ không di
        # chuyển rõ trên mặt phẳng ảnh (x, y) — nếu chỉ tính 2D, góc gần
        # như không đổi và rep không bao giờ được đếm. z từ MediaPipe kém
        # ổn định hơn x/y nên đây là điều chỉnh cần theo dõi thực tế.
        left_knee_angle: float | None = None
        right_knee_angle: float | None = None

        if _visible(left_hip, left_knee, left_ankle):
            left_knee_angle = calculate_angle_3d(left_hip, left_knee, left_ankle)

        if _visible(right_hip, right_knee, right_ankle):
            right_knee_angle = calculate_angle_3d(right_hip, right_knee, right_ankle)

        # Lấy góc gối trung bình để đếm rep
        knee_angle = _avg(left_knee_angle, right_knee_angle)

        # --- Kiểm tra độ sâu ---
        phase = self.rep_counter.phase.value
        if knee_angle is not None:
            self.rep_counter.update(knee_angle)
            phase = self.rep_counter.phase.value

            # Chấm độ sâu tại ĐÚNG LÚC đảo chiều đi lên, không phải mọi frame
            # đang đi lên. Điều kiện cũ `phase in ("bottom","going_up") and góc >
            # ngưỡng` không bao giờ đúng được: ở BOTTOM góc luôn ≤ ngưỡng (nếu
            # không đã chuyển phase), còn ở GOING_UP góc đương nhiên lớn hơn —
            # đó là định nghĩa của việc đi lên. Kết quả là một rep hoàn hảo vẫn
            # bị báo lỗi suốt lúc đứng lên, TTS đọc oan và điểm chính xác tụt
            # (đo được: rep squat chuẩn chỉ đạt 64,5%).
            if self.rep_counter.shallow_reversal:
                errors.append("Xuống chưa đủ sâu — gối cần gập thêm (mục tiêu < 90°).")

        # --- Kiểm tra gối vượt mũi chân ---
        # Tra ngưỡng một lần rồi dùng lại cho cả hai bên: `analyze` chạy mỗi
        # frame nên tránh tra dict hai lần cho cùng một giá trị.
        overshoot = self.threshold("knee_overshoot", KNEE_OVERSHOOT_RATIO)
        if _visible(left_knee, left_foot) and left_knee_angle is not None:
            if left_knee.x > left_foot.x + overshoot:
                errors.append("Gối trái vượt quá mũi chân — hãy đẩy hông về sau.")

        if _visible(right_knee, right_foot) and right_knee_angle is not None:
            # Gối phải ở phía ngược lại trong không gian ảnh
            if right_knee.x < right_foot.x - overshoot:
                errors.append("Gối phải vượt quá mũi chân — hãy đẩy hông về sau.")

        # --- Kiểm tra lưng thẳng (góc vai-hông-gối) ---
        back_angle: float | None = None
        left_back_ok = _visible(left_shoulder, left_hip, left_knee)
        right_back_ok = _visible(right_shoulder, right_hip, right_knee)

        if left_back_ok:
            back_angle = calculate_angle(left_shoulder, left_hip, left_knee)
        elif right_back_ok:
            back_angle = calculate_angle(right_shoulder, right_hip, right_knee)

        if back_angle is not None and back_angle < self.threshold("back_straight_min", BACK_STRAIGHT_MIN):
            errors.append(f"Lưng bị cúi quá (góc {back_angle:.0f}°) — giữ ngực thẳng và nhìn về phía trước.")

        # --- Tổng hợp kết quả ---
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
            keypoints=_visible_points({
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
