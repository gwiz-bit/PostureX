"""Chấm điểm "độ giống bài mẫu" thời gian thực — so chuỗi góc khớp đang tập
với chuẩn trích từ video mẫu (`reference_library.py`), CỘNG THÊM vào hệ
rep-counting/ngưỡng góc hiện có chứ không thay thế (xem CHANGELOG
11/09/2026 (3)).

Một instance RIÊNG cho mỗi phiên WebSocket — cùng nguyên tắc với
`KeypointSmoother`: giữ trạng thái (cửa sổ góc gần nhất) theo từng phiên,
không dùng chung giữa các người tập.

## Thuật toán: Subsequence DTW

So một CỬA SỔ TRƯỢT `window` frame gần nhất của chuỗi live với TOÀN BỘ chuẩn
tham chiếu, cho phép điểm bắt đầu/kết thúc khớp tự do trong chuẩn (khác DTW
cổ điển ép hai đầu cố định) — vì người đang tập dở chỉ ở MỘT ĐOẠN của chu kỳ
rep tại một thời điểm, không phải cả chu kỳ. Xác nhận qua
`backend/scripts/dtw_prototype.py`: so khớp với chính chuẩn cho đúng
100/100, ~1ms/lần cập nhật trên VPS 2 vCPU — không đáng kể so với pose
estimation 30-60ms/frame.

## Chặn "đứng yên vẫn được điểm cao"

Prototype phát hiện: DTW không giới hạn số lần "dính" vào đúng một frame
chuẩn, nên đứng yên ở một tư thế NẰM TRONG phạm vi chuyển động của bài (vd
giữa chừng squat) vẫn ra điểm không thấp — vì DTW luôn tìm được MỘT điểm
chuẩn gần giá trị hiện tại rồi lặp lại nó nhiều lần với chi phí gần 0.

Sửa bằng một chặn đơn giản trước khi chạy DTW: nếu biên độ (max-min) của
chính cửa sổ live gần như không đổi (< `MIN_LIVE_RANGE_DEGREES`), coi đó là
"không thấy chuyển động rep nào" và trả thẳng điểm 0 — không cần DTW phân
xử làm gì vì đứng yên thì không thể đang "khớp" với một chuyển động có thật.
Không dùng ràng buộc step-pattern đầy đủ (giới hạn số bước lặp cùng cột
trong chính DTW) vì tốn thêm một chiều trạng thái trong quy hoạch động — chặn
này rẻ hơn nhiều và nhắm thẳng vào đúng trường hợp lỗi đã đo được.
"""

from __future__ import annotations

from collections import deque

from app.ml.analyzers.reference_joints import primary_joints_for
from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from app.ml.reference_library import ReferenceMotion, get_reference

WINDOW = 30
MIN_LIVE_RANGE_DEGREES = 8.0
# "Không đáng lệch nào" ứng với điểm 0; hiệu chỉnh theo cảm quan, không đo
# trên người thật — CHƯA XÁC NHẬN, cùng tình trạng với mọi ngưỡng khác trong
# dự án lúc mới viết (xem CHANGELOG 06/09/2026, 01/09/2026...).
SCALE_DEGREES = 30.0


def _dtw_subsequence_distance(query: list[float], reference: tuple[float, ...]) -> float:
    n, m = len(query), len(reference)
    prev = [0.0] * (m + 1)
    for i in range(1, n + 1):
        cur = [float("inf")] * (m + 1)
        qi = query[i - 1]
        for j in range(1, m + 1):
            cost = abs(qi - reference[j - 1])
            cur[j] = cost + min(prev[j], cur[j - 1], prev[j - 1])
        prev = cur
    return min(prev[1:]) / n


class SimilarityScorer:
    """Tạo MỘT instance riêng cho mỗi phiên WebSocket (giống `KeypointSmoother`).

    `update()` trả `None` khi: bài không có chuẩn tham chiếu, hoặc chưa phát
    hiện được người ở frame này, hoặc cửa sổ live chưa đủ dữ liệu — `None`
    nghĩa là "chưa có điểm để hiển thị", KHÔNG phải điểm 0; route đọc `None`
    thì bỏ qua field này (giữ nguyên hành vi cũ cho bài chưa có chuẩn).
    """

    def __init__(self, exercise: str, window: int = WINDOW) -> None:
        self._reference: ReferenceMotion | None = get_reference(exercise)
        self._joints: tuple[str, str, str] | None = (
            primary_joints_for(self._reference.analyzer) if self._reference else None
        )
        self._window_size = window
        self._window: deque[float] = deque(maxlen=window)

    @property
    def has_reference(self) -> bool:
        return self._reference is not None

    def update(self, keypoints: dict[str, Keypoint]) -> float | None:
        if self._reference is None or self._joints is None:
            return None
        a, b, c = (keypoints[j] for j in self._joints)
        # PHẢI dùng đúng phép chiếu đã chọn lúc trích chuẩn (xem docstring
        # `ReferenceMotion.projection`) — trộn 2D live với chuẩn 3D (hay
        # ngược lại) sẽ so hai đại lượng khác đơn vị, điểm số vô nghĩa.
        angle = (
            calculate_angle(a, b, c)
            if self._reference.projection == "x/y"
            else calculate_angle_3d(a, b, c)
        )
        self._window.append(angle)
        if len(self._window) < self._window_size:
            return None

        window_list = list(self._window)
        if max(window_list) - min(window_list) < MIN_LIVE_RANGE_DEGREES:
            return 0.0

        distance = _dtw_subsequence_distance(window_list, self._reference.angle_series)
        return max(0.0, 100.0 * (1 - distance / SCALE_DEGREES))
