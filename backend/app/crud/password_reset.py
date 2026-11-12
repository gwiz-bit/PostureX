"""CRUD + logic cho mã 6 số đặt lại mật khẩu.

Cùng khuôn với OTP đăng ký (crud/otp.py): mỗi người chỉ có MỘT mã còn hiệu lực
(mã mới nhất), sống RESET_CODE_EXPIRE_MINUTES phút, nhập sai MAX_RESET_ATTEMPTS
lần thì mã bị huỷ và phải xin mã mới.
"""

import hmac
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_reset_code
from app.models.password_reset_token import PasswordResetToken
from app.models.user import User

# Quyết định của nhóm (12/11/2026): tối đa 10 lần nhập sai cho mỗi mã. Với mã 6 số
# (1 triệu khả năng) xác suất đoán trúng trong 10 lần là 1/100.000 cho mỗi mã.
MAX_RESET_ATTEMPTS = 10


def _generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _is_expired(token: PasswordResetToken) -> bool:
    expires_at = token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    return expires_at < datetime.now(timezone.utc)


async def create_reset_token(db: AsyncSession, user: User) -> str:
    """Tạo mã 6 số mới cho user, trả về mã GỐC (chỉ dùng để gửi email — DB chỉ lưu
    bản HMAC). Mọi mã cũ chưa dùng của user bị huỷ: chỉ mã trong email mới nhất có tác dụng."""
    await db.execute(
        update(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.used == False)  # noqa: E712
        .values(used=True)
    )
    code = _generate_code()
    db.add(
        PasswordResetToken(
            user_id=user.id,
            code_hash=hash_reset_code(user.id, code),
            expires_at=datetime.now(timezone.utc)
            + timedelta(minutes=settings.RESET_CODE_EXPIRE_MINUTES),
            attempts=0,
        )
    )
    await db.flush()
    return code


async def consume_reset_code(db: AsyncSession, user: User, code: str) -> bool:
    """Kiểm tra mã của user. Đúng (còn hạn, chưa dùng, chưa hết lượt) → đánh dấu đã
    dùng và trả True. Sai → tăng `attempts`, trả False. Caller phải commit cả khi sai
    để số lần nhập sai được lưu lại."""
    result = await db.execute(
        select(PasswordResetToken)
        .where(PasswordResetToken.user_id == user.id, PasswordResetToken.used == False)  # noqa: E712
        .order_by(PasswordResetToken.created_at.desc(), PasswordResetToken.id.desc())
        .limit(1)
    )
    token = result.scalar_one_or_none()
    if token is None or _is_expired(token):
        return False

    if token.attempts >= MAX_RESET_ATTEMPTS:
        # Hết lượt: huỷ hẳn mã, không chấm `code` nữa dù trùng hay không.
        token.used = True
        await db.flush()
        return False

    if not hmac.compare_digest(token.code_hash, hash_reset_code(user.id, code)):
        token.attempts += 1
        if token.attempts >= MAX_RESET_ATTEMPTS:
            token.used = True
        await db.flush()
        return False

    token.used = True
    await db.flush()
    return True
