"""Model bảng PasswordResetTokens — token đặt lại mật khẩu qua email.

Bảng do backend tự quản lý (như email_otps/videos/workouts), tạo qua
create_tables.py — không nằm trong sql/postureX123_schema.sql gốc.
"""

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    # SHA-256 hex digest (64 ký tự) của raw token — không bao giờ lưu raw
    # token trong DB, cùng nguyên tắc với mật khẩu: nếu DB bị lộ, kẻ tấn
    # công không thể tự đặt lại mật khẩu người khác từ dữ liệu rò rỉ.
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User")
