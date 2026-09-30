"""Model bảng Devices (schema PostureX v2).

Khác với bảng device_tokens (dùng cho FCM push notification):
bảng Devices lưu thông tin thiết bị vật lý của user để WorkoutSessions biết
phiên tập chạy trên thiết bị nào, và lưu PushToken dự phòng cho kênh thay thế.

Thay đổi so với v1: Platform thay cho DeviceType + OsName, thêm PushToken,
bỏ IsActive, đổi RegisteredAt → CreatedAt.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Device(Base):
    """Thiết bị di động/máy tính đã dùng để tập — one user có thể nhiều device."""

    __tablename__ = "Devices"

    id: Mapped[int] = mapped_column("DeviceId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    device_name: Mapped[str | None] = mapped_column("DeviceName", String(100), nullable=True)
    # iOS / Android / Web
    platform: Mapped[str | None] = mapped_column("Platform", String(20), nullable=True)
    os_version: Mapped[str | None] = mapped_column("OsVersion", String(30), nullable=True)
    app_version: Mapped[str | None] = mapped_column("AppVersion", String(30), nullable=True)
    push_token: Mapped[str | None] = mapped_column("PushToken", String(500), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column("LastUsedAt", DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
