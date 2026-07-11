"""Model bảng Notifications — thông báo trong app.

Bảng này thuộc schema PostureX của nhóm (sql/postureX123_schema.sql), giống
Users/Roles: cột đặt tên PascalCase và **không** do create_tables.py quản lý.
Tuyệt đối không thêm bảng này vào DROP_SQL của create_tables.py.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Notification(Base):
    __tablename__ = "Notifications"

    id: Mapped[int] = mapped_column("NotificationId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column("Title", String(150), nullable=False)
    body: Mapped[str | None] = mapped_column("Body", String(500), nullable=True)
    # Nhãn tự do (vd: "payment", "workout") để client lọc/chọn icon.
    type: Mapped[str | None] = mapped_column("Type", String(30), nullable=True)
    is_read: Mapped[bool] = mapped_column("IsRead", Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
