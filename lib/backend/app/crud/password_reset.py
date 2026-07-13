"""CRUD + logic cho token đặt lại mật khẩu."""

import hmac
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_reset_token
from app.models.password_reset_token import PasswordResetToken
from app.models.user import User


async def create_reset_token(db: AsyncSession, user: User) -> str:
    """Tạo token đặt lại mật khẩu mới, trả về RAW token — chỉ tồn tại
    trong bộ nhớ đủ lâu để gửi email, DB chỉ lưu bản hash (xem
    hash_reset_token)."""
    raw_token = secrets.token_urlsafe(32)
    reset = PasswordResetToken(
        user_id=user.id,
        token_hash=hash_reset_token(raw_token),
        expires_at=datetime.now(timezone.utc)
        + timedelta(minutes=settings.RESET_TOKEN_EXPIRE_MINUTES),
    )
    db.add(reset)
    await db.flush()
    return raw_token


async def get_valid_reset_token(db: AsyncSession, raw_token: str) -> PasswordResetToken | None:
    """Tìm bản ghi token hợp lệ (tồn tại, chưa dùng, chưa hết hạn) khớp
    với raw_token đã cho.

    Tra cứu bằng WHERE token_hash = ... (index, nhanh — so khớp một mã
    băm không phải secret gốc nên bản thân bước tra cứu này không rò rỉ
    thời gian có ý nghĩa), sau đó xác nhận lại bằng hmac.compare_digest
    như một lớp phòng thủ bổ sung trước khi tin kết quả — đúng chuẩn thực
    hành khi so khớp giá trị liên quan tới bảo mật, thay vì dùng "==".
    """
    token_hash = hash_reset_token(raw_token)
    result = await db.execute(
        select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
    )
    token = result.scalar_one_or_none()
    if token is None or not hmac.compare_digest(token.token_hash, token_hash):
        return None
    if token.used:
        return None

    expires_at = token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        return None

    return token


async def mark_reset_token_used(db: AsyncSession, token: PasswordResetToken) -> None:
    token.used = True
    await db.flush()
