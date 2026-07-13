"""Phân tích kỹ thuật squat: độ sâu, gối vượt mũi chân, lưng thẳng."""

from app.ml.angle_utils import calculate_angle
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles, Point

# Ngưỡng góc (độ)
KNEE_DEPTH_THRESHOLD = 95.0      # Gối phải gập ≤ ngưỡng này mới đủ sâu
KNEE_OVERSHOOT_RATIO = 0.05      # Gối không được vượt qua mũi chân quá 5% chiều rộng frame
BACK_STRAIGHT_MIN = 150.0        # Góc hông-vai-cổ phải ≥ ngưỡng này (lưng thẳng)
VISIBILITY_THRESHOLD = 0.5       # Chỉ xét khớp nếu độ tin cậy đủ cao


class SquatAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật squat và trả feedback tiếng Việt."""

    def __init__(self, rep_counter: RepCounter | None = None) -> None:
        super().__init__(rep_counter or RepCounter(down_threshold=95.0, up_threshold=160.0))

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
        left_knee_angle: float | None = None
        right_knee_angle: float | None = None

        if _visible(left_hip, left_knee, left_ankle):
            left_knee_angle = calculate_angle(left_hip, left_knee, left_ankle)

        if _visible(right_hip, right_knee, right_ankle):
            right_knee_angle = calculate_angle(right_hip, right_knee, right_ankle)

        # Lấy góc gối trung bình để đếm rep
        knee_angle = _avg(left_knee_angle, right_knee_angle)

        # --- Kiểm tra độ sâu ---
        phase = self.rep_counter.phase.value
        if knee_angle is not None:
            self.rep_counter.update(knee_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.phase.value in ("bottom", "going_up"):
                if knee_angle > KNEE_DEPTH_THRESHOLD:
                    errors.append("Xuống chưa đủ sâu — gối cần gập thêm (mục tiêu < 90°).")

        # --- Kiểm tra gối vượt mũi chân ---
        if _visible(left_knee, left_foot) and left_knee_angle is not None:
            if left_knee.x > left_foot.x + KNEE_OVERSHOOT_RATIO:
                errors.append("Gối trái vượt quá mũi chân — hãy đẩy hông về sau.")

        if _visible(right_knee, right_foot) and right_knee_angle is not None:
            # Gối phải ở phía ngược lại trong không gian ảnh
            if right_knee.x < right_foot.x - KNEE_OVERSHOOT_RATIO:
                errors.append("Gối phải vượt quá mũi chân — hãy đẩy hông về sau.")

        # --- Kiểm tra lưng thẳng (góc vai-hông-gối) ---
        back_angle: float | None = None
        left_back_ok = _visible(left_shoulder, left_hip, left_knee)
        right_back_ok = _visible(right_shoulder, right_hip, right_knee)

        if left_back_ok:
            back_angle = calculate_angle(left_shoulder, left_hip, left_knee)
        elif right_back_ok:
            back_angle = calculate_angle(right_shoulder, right_hip, right_knee)

        if back_angle is not None and back_angle < BACK_STRAIGHT_MIN:
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


# --- Helper functions ---

def _visible(*kps: Keypoint) -> bool:
    """Trả True nếu tất cả keypoint có visibility đủ cao."""
    return all(kp.visibility >= VISIBILITY_THRESHOLD for kp in kps)


def _avg(a: float | None, b: float | None) -> float | None:
    """Trả trung bình hai giá trị; nếu cả hai None thì trả None."""
    if a is not None and b is not None:
        return (a + b) / 2
    return a if a is not None else b


def _visible_points(joints: dict[str, Keypoint]) -> dict[str, Point]:
    """Chuyển các Keypoint đủ tin cậy thành Point để trả về client vẽ
    skeleton — bỏ qua khớp che khuất/không rõ thay vì gửi tọa độ rác."""
    return {
        name: Point(x=kp.x, y=kp.y, visibility=kp.visibility)
        for name, kp in joints.items()
        if kp.visibility >= VISIBILITY_THRESHOLD
    }
