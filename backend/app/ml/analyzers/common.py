"""Helper dùng chung cho mọi analyzer bài tập — tách ra từ squat.py để 8+
analyzer sau này không copy-paste lại cùng 3 hàm nhỏ này."""

import math

from app.ml.pose_estimator import Keypoint
from app.schemas.analysis import Point

VISIBILITY_THRESHOLD = 0.5  # Chỉ xét khớp nếu độ tin cậy đủ cao

# Gối được phép vượt mũi chân tối đa bao nhiêu LẦN chiều dài chân (hông → cổ chân).
# 0,15 = đúng mức ngưỡng cũ (5% chiều rộng khung) quy ra cho người cỡ trung bình
# (chân chiếm ~1/3 chiều cao khung), nên bật cơ chế mới không đổi hành vi với người
# đứng ở khoảng cách bình thường. ƯỚC LƯỢNG, chưa đo trên người thật.
KNEE_OVERSHOOT_LEG_RATIO = 0.15


def knee_passes_toe(
    knee: Keypoint,
    foot: Keypoint,
    hip: Keypoint,
    ankle: Keypoint,
    *,
    outward: int,
    max_ratio: float,
) -> bool:
    """Gối có vượt mũi chân quá `max_ratio` × chiều dài chân không.

    Ngưỡng cũ là tỉ lệ theo CHIỀU RỘNG KHUNG HÌNH (0,05), nên phụ thuộc người đứng gần
    hay xa, to hay nhỏ: cùng một lỗi kỹ thuật, người chiếm nhiều khung bị báo khi gối
    chỉ vượt 10% chiều dài chân, người chiếm ít khung phải vượt tới 31% (đo bằng mô
    phỏng 01/10/2026). Đo theo chiều dài chân của CHÍNH người đó thì không còn phụ
    thuộc kích thước hay khoảng cách.

    Mọi khoảng cách đều nhân `aspect` cho x (xem `angle_utils`) để hai trục cùng thang
    pixel — nếu không, cùng một người ở khung dọc và khung ngang cho kết quả khác nhau.

    `outward`: +1 cho chân trái (mũi chân ở bên +x của gối), −1 cho chân phải — người
    quay mặt vào camera nên hai chân đối xứng.
    """
    s = knee.aspect
    leg_length = math.hypot((hip.x - ankle.x) * s, hip.y - ankle.y)
    if leg_length < 1e-6:
        return False
    overshoot = (knee.x - foot.x) * outward * s
    return overshoot > max_ratio * leg_length


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
    kéo trung bình lên, không bao giờ chạm ngưỡng "đang làm việc".

    KHÔNG dùng cho analyzer có quy ước NGƯỢC (nghỉ = góc NHỎ, cùng phía
    `down_threshold`) — xem `active_side_max()` bên dưới, viết riêng cho
    `CalfRaiseAnalyzer` sau khi rà lại 13/09/2026."""
    if a is not None and b is not None:
        return min(a, b)
    return a if a is not None else b


def active_side_max(a: float | None, b: float | None) -> float | None:
    """Trả góc LỚN HƠN trong hai bên — đối xứng với `active_side()`, dùng cho
    analyzer có quy ước góc NGƯỢC LẠI: nghỉ = góc NHỎ (cùng phía
    `down_threshold`), làm việc = góc tăng dần lên.

    `CalfRaiseAnalyzer` là trường hợp DUY NHẤT hiện có kiểu này: chân nghỉ
    (bàn chân áp sàn, không tham gia bài) giữ nguyên góc NHỎ ~90° suốt bài —
    cùng phía `down_threshold` (85°) chứ không phải `up_threshold` (130°) như
    mọi analyzer khác dùng `active_side()`. Nếu áp `active_side()` (chọn
    `min()`) ở đây, hàm sẽ LUÔN chọn nhầm thành chân đang nghỉ (góc của nó
    hiếm khi lớn hơn chân đang nhón), khiến rep không bao giờ đếm được mà
    không có lỗi nào báo — đây chính là bẫy đã né khi loại CalfRaise khỏi đợt
    single_side đầu tiên (CHANGELOG 13/09/2026). `max()` sửa đúng: chân đang
    nhón tăng dần lên ~140°, vượt hẳn chân nghỉ đứng yên ~90°, nên `max()`
    luôn chọn đúng chân đang làm việc; ở đáy rep (cả hai gần ~90°) chọn bên
    nào cũng vô hại vì cả hai đều nằm trong vùng "đang nghỉ"."""
    if a is not None and b is not None:
        return max(a, b)
    return a if a is not None else b


def visible_points(joints: dict[str, Keypoint]) -> dict[str, Point]:
    """Chuyển các Keypoint đủ tin cậy thành Point để trả về client vẽ
    skeleton overlay — bỏ qua khớp che khuất/không rõ thay vì gửi tọa độ rác."""
    return {
        name: Point(x=kp.x, y=kp.y, visibility=kp.visibility)
        for name, kp in joints.items()
        if kp.visibility >= VISIBILITY_THRESHOLD
    }
