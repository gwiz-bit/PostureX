"""Múi giờ Việt Nam — một chỗ duy nhất.

Người dùng ở Việt Nam, nên mọi khái niệm "hôm nay" / "8 giờ tối" trong hệ thống
phải tính theo giờ VN, **không** theo UTC. Nếu tính theo UTC thì 7 giờ sáng ở VN
vẫn đang là "hôm qua" — hạn mức ngày reset trễ, tổng kết ngày gửi sai thời điểm.

Cột `created_at` trong DB lưu theo UTC. Nên mọi truy vấn kiểu "trong ngày hôm nay"
đều phải: lấy mốc đầu ngày theo giờ VN → đổi sang UTC → mới đem đi so sánh.
Đó chính là việc của `vn_day_start_utc()`.
"""

from datetime import date, datetime, time, timedelta, timezone

VN_TZ = timezone(timedelta(hours=7))


def vn_now() -> datetime:
    """Thời điểm hiện tại theo giờ VN."""
    return datetime.now(VN_TZ)


def vn_day_start_utc(day: date | None = None) -> datetime:
    """Mốc 00:00 giờ VN của `day` (mặc định hôm nay), quy về UTC.

    Dùng để so với các cột DateTime lưu theo UTC.
    """
    day = day or vn_now().date()
    return datetime.combine(day, time.min, tzinfo=VN_TZ).astimezone(timezone.utc)
