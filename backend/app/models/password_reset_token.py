"""Model bảng password_reset_codes — mã 6 số đặt lại mật khẩu qua email.

Bảng do backend tự quản lý (như email_otps/videos/workouts), tạo qua
ensure_tables.py — không cần ALTER TABLE bằng tay khi deploy.

Lịch sử (12/11/2026): trước đây là bảng `password_reset_tokens` lưu token dài
(`secrets.token_urlsafe(32)`). Nhóm muốn mã ngắn 6 số giống OTP đăng ký nên đổi
sang bảng MỚI thay vì sửa bảng cũ, vì cần thêm cột `attempts` và bỏ ràng buộc
UNIQUE của cột hash (mã 6 số của hai người có thể trùng nhau), mà ensure_tables.py
chỉ biết tạo bảng còn thiếu, không thêm/sửa cột. Bảng cũ `password_reset_tokens`
không còn code nào dùng — xoá được bằng `DROP TABLE password_reset_tokens`.
Tên lớp/tên file giữ nguyên để khỏi phải sửa các chỗ import.
"""

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class PasswordResetToken(Base):
    __tablename__ = "password_reset_codes"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    # HMAC-SHA256 (khoá SECRET_KEY, kèm user_id) của mã 6 số — không lưu mã gốc,
    # xem core/security.py::hash_reset_code. KHÔNG unique: hai người có thể nhận
    # cùng một mã 6 số.
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    used: Mapped[bool] = mapped_column(Boolean, default=False)
    # Số lần nhập sai — đủ MAX_RESET_ATTEMPTS thì mã bị huỷ (crud/password_reset.py).
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User")
