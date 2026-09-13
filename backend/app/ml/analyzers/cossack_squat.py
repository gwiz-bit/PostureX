"""Phân tích kỹ thuật Cossack Squat: squat sang ngang (mặt phẳng trán), luôn
xác định đúng chân đang chịu lực bằng `min()` hai gối.

Cossack Squat là squat LỆCH TRỌNG TÂM: đứng chân rộng (kiểu sumo), dồn trọng
lượng sang MỘT bên, gối bên đó gập sâu (như single-leg squat) trong khi chân
kia gần như duỗi thẳng, chìa ra ngoài, gót có thể nhấc lên. Chuyển động diễn
ra ở MẶT PHẲNG TRÁN (sang ngang), khác hẳn giả định nhìn NGHIÊNG (mặt phẳng
đứng dọc) của `SquatAnalyzer`/`LungeAnalyzer`.

Dùng ĐÚNG công thức góc gối (hông-gối-cổ chân, `calculate_angle_3d`) như
Squat/Lunge, và cùng cơ chế `min()` hai gối như `LungeAnalyzer` (xem docstring
class đó: "gối nào đang gập sâu hơn chính là chân đang chịu lực ở thời điểm
đó") — KHÔNG cần cờ single_side, vì đây LUÔN là cơ chế hai chân luân phiên,
giống hệt cách Lunge không cần cờ đó (khác Kickback/HipAbduction — những bài
luôn tập MỘT chân trong khi chân kia đứng yên tuyệt đối).

`calculate_angle_3d` tính góc bằng vector 3D thật (x, y, z — xem
`angle_utils.py`) nên không phụ thuộc người đang quay mặt hay quay ngang vào
camera, chỉ phụ thuộc MediaPipe ước lượng đúng độ sâu (z) — đã xác nhận qua
`HipAbductionAnalyzer` (CHANGELOG 13/09/2026, bài dạng chân sang ngang), áp
dụng lại nguyên lý đó ở đây cho squat sang ngang.

CỐ TÌNH BỎ HẲN hai kiểm tra phụ của Squat/Lunge, không cố gắng tái chế:
- Gối vượt mũi chân (`knee_overshoot`) — so sánh toạ độ x 2D, giả định camera
  nhìn NGHIÊNG (trục x = trước-sau cơ thể). Với camera nhìn TRỰC DIỆN cần cho
  chuyển động sang ngang, trục x lại là trái-phải — phép so sánh cũ sẽ đo
  nhầm sang một ý nghĩa khác hẳn (gối đổ vào trong/valgus) mà chưa có ngưỡng
  nào được kiểm chứng. Bỏ hẳn thay vì đoán bừa, đúng tinh thần "thà thiếu còn
  hơn chấm sai".
- Lưng thẳng (`back_straight_min`) — chưa đủ tự tin về ngưỡng góc thân cho
  chuyển động sang ngang (khác hẳn cúi người ra trước của squat/lunge chuẩn).
  Đây là analyzer ĐẦU TIÊN của dự án đo squat ở mặt phẳng trán, chưa có gì để
  đối chiếu — để dành hiệu chỉnh sau khi có người test thật.

Tái dùng ĐÚNG khoá `knee_depth`/`stand_up_min` đã có của Squat/Lunge — cùng ý
nghĩa vật lý ("gối gập dưới góc này mới đủ sâu" / "lên trên góc này là đã
đứng thẳng"), không cần khoá mới, không cần sửa `thresholds.py`/
`posture_rule.py`.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Cùng mức ước lượng ban đầu như LungeAnalyzer — ƯỚC LƯỢNG theo hình học,
# CHƯA đo trên người thật. Đây là lần đầu ước lượng cho chuyển động sang
# ngang nên độ tin cậy thấp hơn cả squat/lunge lúc mới viết (01/09/2026).
KNEE_DEPTH_THRESHOLD = 100.0
STAND_UP_MIN = 160.0


class CossackSquatAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật Cossack squat (squat sang ngang) và trả feedback tiếng Việt."""

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
                up_threshold=t.get("stand_up_min", STAND_UP_MIN),
            ),
            thresholds,
        )

    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        errors: list[str] = []

        left_hip = keypoints[23]
        right_hip = keypoints[24]
        left_knee = keypoints[25]
        right_knee = keypoints[26]
        left_ankle = keypoints[27]
        right_ankle = keypoints[28]

        left_knee_angle: float | None = None
        right_knee_angle: float | None = None

        if is_visible(left_hip, left_knee, left_ankle):
            left_knee_angle = calculate_angle_3d(left_hip, left_knee, left_ankle)
        if is_visible(right_hip, right_knee, right_ankle):
            right_knee_angle = calculate_angle_3d(right_hip, right_knee, right_ankle)

        loaded_knee_angle: float | None = None
        if left_knee_angle is not None and right_knee_angle is not None:
            loaded_knee_angle = min(left_knee_angle, right_knee_angle)
        elif left_knee_angle is not None:
            loaded_knee_angle = left_knee_angle
        elif right_knee_angle is not None:
            loaded_knee_angle = right_knee_angle

        phase = self.rep_counter.phase.value
        if loaded_knee_angle is not None:
            self.rep_counter.update(loaded_knee_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append(
                    "Chưa hạ đủ sâu — dồn trọng lượng hẳn sang một bên, gập sâu gối bên đó."
                )

        return FrameAnalysisResult(
            rep_count=self.rep_counter.rep_count,
            errors=errors,
            correct=len(errors) == 0,
            key_angles=KeyAngles(left_knee=left_knee_angle, right_knee=right_knee_angle),
            phase=phase,
            keypoints=visible_points({
                "left_hip": left_hip,
                "right_hip": right_hip,
                "left_knee": left_knee,
                "right_knee": right_knee,
                "left_ankle": left_ankle,
                "right_ankle": right_ankle,
            }),
        )
