"""Mã xác nhận xoá tài khoản qua email (luồng web /delete-account).

Chỉ lưu bản băm HMAC của mã (khoá là SECRET_KEY, có kèm user_id) — lộ DB cũng
không đọc được mã còn hiệu lực. Mã 6 chữ số ít entropy nên chống đoán mò bằng
giới hạn số lần thử và thời hạn ngắn, không bằng độ dài.
"""

import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.account_deletion import AccountDeletionRequest
from app.models.user import User

CODE_EXPIRE_MINUTES = 15
MAX_ATTEMPTS = 5
# Chống bấm gửi liên tục làm tràn hộp thư của chính chủ: trong khoảng này chỉ gửi 1 mã.
RESEND_COOLDOWN_SECONDS = 60


def _hash_code(user_id: int, code: str) -> str:
    return hmac.new(
        settings.SECRET_KEY.encode(), f"{user_id}:{code}".encode(), hashlib.sha256
    ).hexdigest()


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


async def _latest(db: AsyncSession, user_id: int) -> AccountDeletionRequest | None:
    return (
        await db.execute(
            select(AccountDeletionRequest)
            .where(AccountDeletionRequest.user_id == user_id)
            .order_by(AccountDeletionRequest.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()


async def create_request(db: AsyncSession, user: User) -> str | None:
    """Tạo mã mới, trả về mã GỐC để gửi email. Trả None nếu vừa có mã được gửi
    cách đây chưa tới RESEND_COOLDOWN_SECONDS (bỏ qua, không gửi thêm)."""
    now = datetime.now(timezone.utc)
    previous = await _latest(db, user.id)
    if previous is not None:
        age = (now - _as_utc(previous.created_at)).total_seconds()
        if age < RESEND_COOLDOWN_SECONDS:
            return None

    # Mã cũ chưa dùng hết hiệu lực ngay khi có mã mới.
    await db.execute(delete(AccountDeletionRequest).where(AccountDeletionRequest.user_id == user.id))
    code = f"{secrets.randbelow(1_000_000):06d}"
    db.add(
        AccountDeletionRequest(
            user_id=user.id,
            code_hash=_hash_code(user.id, code),
            expires_at=now + timedelta(minutes=CODE_EXPIRE_MINUTES),
        )
    )
    await db.flush()
    return code


async def verify_code(db: AsyncSession, user: User, code: str) -> bool:
    """Kiểm tra mã. Mỗi lần gọi tính là một lần thử; quá MAX_ATTEMPTS thì mã bị huỷ.
    Commit ngay khi sai để số lần thử được ghi nhận (route sau đó ném 400 và
    get_db sẽ rollback mọi thứ chưa commit)."""
    request = await _latest(db, user.id)
    if request is None:
        return False

    if _as_utc(request.expires_at) < datetime.now(timezone.utc) or request.attempts >= MAX_ATTEMPTS:
        await db.delete(request)
        await db.commit()
        return False

    request.attempts += 1
    if not hmac.compare_digest(request.code_hash, _hash_code(user.id, code.strip())):
        await db.commit()
        return False

    return True
