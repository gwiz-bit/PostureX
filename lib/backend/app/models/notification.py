"""Model bảng AdminNotifications — thông báo admin gửi broadcast tới user.

Đặt tên bảng "admin_notifications" (không phải "notifications") vì schema
PostureX gốc (sql/postureX123_schema.sql) đã có sẵn bảng Notifications —
thông báo riêng theo từng user (UserId, IsRead...), khác khái niệm với
thông báo broadcast ở đây. Trùng tên sẽ đụng bảng core đó (MySQL
lower_case_table_names=1 khiến "notifications" == "Notifications")."""

from datetime import datetime, timezone

from sqlalchemy import DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

# Đối tượng nhận — lọc theo gói hiện tại của user (suy ra từ giao dịch gần
# nhất, xem crud/subscription.py), không phải 1 cột riêng trên User.
AUDIENCE_ALL = "all"
AUDIENCE_PREMIUM = "premium"  # đang có gói trả phí (Advanced/Pro)
AUDIENCE_FREE = "free"


class Notification(Base):
    __tablename__ = "admin_notifications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    audience: Mapped[str] = mapped_column(String(20), default=AUDIENCE_ALL)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
