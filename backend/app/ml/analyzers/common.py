"""Helper dùng chung cho mọi analyzer bài tập — tách ra từ squat.py để 8+
analyzer sau này không copy-paste lại cùng 3 hàm nhỏ này."""

from app.ml.pose_estimator import Keypoint
from app.schemas.analysis import Point

VISIBILITY_THRESHOLD = 0.5  # Chỉ xét khớp nếu độ tin cậy đủ cao


def is_visible(*kps: Keypoint) -> bool:
    """Trả True nếu tất cả keypoint có visibility đủ cao."""
    return all(kp.visibility >= VISIBILITY_THRESHOLD for kp in kps)


def avg(a: float | None, b: float | None) -> float | None:
    """Trả trung bình hai giá trị; nếu cả hai None thì trả giá trị còn lại
    (hoặc None nếu cả hai đều None) — dùng khi một bên khớp bị che khuất."""
    if a is not None and b is not None:
        return (a + b) / 2
    return a if a is not None else b


def active_side(a: float | None, b: float | None) -> float | None:
    """Trả góc NHỎ HƠN trong hai bên — dùng cho bài tập một tay/một chân
    (single-arm/single-leg) thay cho `avg()`.

    Mọi analyzer trong dự án đều theo cùng quy ước: `down_threshold` (vị trí
    "đang làm việc" — co/gập/hạ) luôn là góc NHỎ, `up_threshold` (vị trí nghỉ
    — duỗi/đứng thẳng) luôn là góc LỚN. Với bài một bên, bên đang nghỉ giữ
    nguyên góc lớn gần `up_threshold` trong khi bên đang làm việc đi xuống —
    nên bên có góc NHỎ HƠN tại từng thời điểm chính là bên đang thực sự tập,
    bất kể đó là tay/chân nào hay đang luân phiên hai bên (`LungeAnalyzer`
    đã dùng đúng `min()` này cho gối tay trước/sau từ trước, xem docstring
    class đó) — hàm này tổng quát hoá cách làm cùng ý tưởng cho các analyzer
    khác. Dùng trung bình (`avg`) ở đây sẽ sai: bên đang nghỉ giữ góc lớn
    kéo trung bình lên, không bao giờ chạm ngưỡng "đang làm việc"."""
    if a is not None and b is not None:
        return min(a, b)
    return a if a is not None else b


def visible_points(joints: dict[str, Keypoint]) -> dict[str, Point]:
    """Chuyển các Keypoint đủ tin cậy thành Point để trả về client vẽ
    skeleton overlay — bỏ qua khớp che khuất/không rõ thay vì gửi tọa độ rác."""
    return {
        name: Point(x=kp.x, y=kp.y, visibility=kp.visibility)
        for name, kp in joints.items()
        if kp.visibility >= VISIBILITY_THRESHOLD
    }
