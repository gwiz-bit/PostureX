"""Model bảng device_tokens — token FCM của từng thiết bị.

Bảng này **do SQLAlchemy quản lý** (giống videos/workouts/email_otps), không
thuộc schema PostureX của nhóm. Nhưng **tuyệt đối không thêm vào DROP_SQL** của
create_tables.py: xoá bảng này là mọi thiết bị mất đăng ký, người dùng ngừng
nhận push cho tới khi họ mở lại app.

Một user có thể có nhiều token (điện thoại + máy tính bảng), và một token chỉ
thuộc về một user tại một thời điểm — nên `token` là UNIQUE, còn `user_id` thì
không. Khi user B đăng nhập trên máy của user A, token đó phải **chuyển chủ**
chứ không tạo dòng mới (xem `crud/device_token.py`).
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class DeviceToken(Base):
    __tablename__ = "device_tokens"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId"), nullable=False, index=True
    )
    # Token FCM dài ~160+ ký tự, không có giới hạn chính thức — để rộng.
    token: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    platform: Mapped[str | None] = mapped_column(String(20), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False
    )
