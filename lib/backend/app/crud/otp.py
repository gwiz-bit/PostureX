"""CRUD + logic cho mã OTP xác thực email."""

import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.email_otp import EmailOtp
from app.models.user import User


def _generate_code() -> str:
    """Sinh mã OTP 6 chữ số, dùng secrets (an toàn hơn random thường)."""
    return f"{secrets.randbelow(1_000_000):06d}"


async def create_otp(db: AsyncSession, user: User) -> EmailOtp:
    """Tạo OTP mới cho user (mỗi lần gọi tạo 1 bản ghi mới, các mã cũ
    chưa dùng vẫn còn trong bảng nhưng sẽ không khớp nữa vì verify_otp
    chỉ nhận mã mới nhất còn hạn)."""
    otp = EmailOtp(
        user_id=user.id,
        code=_generate_code(),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=settings.OTP_EXPIRE_MINUTES),
    )
    db.add(otp)
    await db.flush()
    return otp


async def verify_otp(db: AsyncSession, user: User, code: str) -> bool:
    """Kiểm tra mã OTP mới nhất, chưa dùng, chưa hết hạn của user.
    Trả về True và đánh dấu đã dùng nếu khớp, ngược lại False."""
    result = await db.execute(
        select(EmailOtp)
        .where(EmailOtp.user_id == user.id, EmailOtp.is_used == False)  # noqa: E712
        .order_by(EmailOtp.created_at.desc())
        .limit(1)
    )
    otp = result.scalar_one_or_none()
    if otp is None:
        return False

    otp.attempts += 1

    expires_at = otp.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        await db.flush()
        return False

    if otp.code != code:
        await db.flush()
        return False

    otp.is_used = True
    await db.flush()
    return True
