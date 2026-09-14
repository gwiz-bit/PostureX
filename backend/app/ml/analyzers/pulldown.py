"""Phân tích kỹ thuật Pulldown/Pull-up (kéo dọc): độ co, lệch hai bên.

Gộp chung Lat Pulldown (kéo tạ xuống) và Pull-up/Chin-up (kéo thân lên) vào
MỘT analyzer vì cả hai cùng một cơ chế góc khuỷu tay — chỉ khác vật nào di
chuyển (tạ hay thân người), còn khuỷu tay đều đi từ duỗi gần thẳng (treo/với
tay lên xà) tới gập sâu (tạ chạm ngực / cằm qua xà).

CỐ TÌNH KHÔNG kiểm lưng thẳng như `RowAnalyzer`: pulldown ngồi trên máy có
chân gập ra trước (không phải đứng cúi người như row), nên góc vai-hông-gối
tự nhiên chỉ còn ~90-100° dù ngồi đúng tư thế — sát ngay ngưỡng 100° của Row,
dễ báo nhầm "lưng cong" cho người ngồi bình thường. Không có kiểm lưng nào ở
đây, chỉ góc khuỷu tay + lệch hai bên.

⚠️ `ELBOW_CONTRACTED_THRESHOLD` sửa 65°→90° ngày 15/09/2026 — thành viên báo
test thật "kéo mỏi tay vẫn không đếm" trên Band Assisted Pull Up. Mô phỏng
lại bằng script (không đoán suông) loại trừ được giả thuyết ban đầu (lấy mẫu
thưa do độ trễ mạng): `RepCounter` vẫn đếm đúng dù chỉ 2-3 mẫu/rep, MIỄN LÀ
góc thực sự chạm ngưỡng tại một thời điểm nào đó — xem test riêng trong
`tests/test_analyzers.py` mô phỏng cả hai kịch bản (thưa mẫu + đủ ROM: vẫn
đếm đúng; đủ mẫu + ROM một phần: không đếm được, đúng bug thật). Vấn đề THẬT
là ngưỡng 65° tự nó — biên độ đó đòi
hỏi cùi chỏ gập gần bằng một pull-up không hỗ trợ hoàn chỉnh, trong khi biến
thể CÓ HỖ TRỢ (band/machine assisted) — đúng đối tượng người mới tập cần hỗ
trợ — nhiều khả năng KHÔNG BAO GIỜ đạt được độ sâu đó dù đã cố hết sức, nên
0 rep không phải lỗi hệ thống mà là ngưỡng đặt sai biên độ thực tế. Không đổi
`RowAnalyzer`/`FacePullAnalyzer` (cùng có ngưỡng 70°) trong đợt này — cả hai
dùng tạ/cáp có thể tự kiểm soát độ sâu (khác pull-up chống lại trọng lượng cơ
thể), chưa có bằng chứng cụ thể nào cho thấy chúng cũng gặp vấn đề tương tự;
để dành, chỉnh nếu test thật xác nhận cũng sai.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import active_side, avg, is_visible, visible_points
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

# Khuỷu tay gập ≤ ngưỡng này mới coi là đã kéo hết (tạ chạm ngực / cằm qua xà).
# ƯỚC LƯỢNG lại 15/09/2026 (từ 65.0) — xem cảnh báo ở docstring module.
ELBOW_CONTRACTED_THRESHOLD = 90.0
# Khuỷu tay duỗi ≥ ngưỡng này mới coi là đã về vị trí bắt đầu (tay gần thẳng,
# treo người hoặc với tay lên xà/thanh kéo).
ELBOW_EXTENDED_THRESHOLD = 160.0
# Chênh lệch góc hai tay quá mức này là kéo lệch bên.
ELBOW_ASYMMETRY_THRESHOLD = 25.0


class PulldownAnalyzer(ExerciseAnalyzer):
    """Phân tích kỹ thuật pulldown/pull-up (kéo dọc) và trả feedback tiếng Việt."""

    SUPPORTS_SINGLE_SIDE = True

    def __init__(
        self,
        rep_counter: RepCounter | None = None,
        thresholds: dict[str, float] | None = None,
        single_side: bool = False,
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
        self._single_side = single_side

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

        elbow_angle = (
            active_side(left_elbow_angle, right_elbow_angle)
            if self._single_side
            else avg(left_elbow_angle, right_elbow_angle)
        )

        phase = self.rep_counter.phase.value
        if elbow_angle is not None:
            self.rep_counter.update(elbow_angle)
            phase = self.rep_counter.phase.value

            if self.rep_counter.shallow_reversal:
                errors.append("Chưa kéo hết — gập khuỷu tay nhiều hơn ở đỉnh mỗi rep.")

        if not self._single_side and left_elbow_angle is not None and right_elbow_angle is not None:
            limit = self.threshold("elbow_asymmetry", ELBOW_ASYMMETRY_THRESHOLD)
            if abs(left_elbow_angle - right_elbow_angle) > limit:
                errors.append("Hai tay kéo không đều — giữ tốc độ và độ co hai bên bằng nhau.")

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
