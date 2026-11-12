"""Xử lý JWT và hash mật khẩu."""

import hashlib
import hmac
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash mật khẩu bằng bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    """So sánh mật khẩu thô với hash."""
    return pwd_context.verify(plain, hashed)


def create_access_token(subject: Any, expires_delta: timedelta | None = None) -> str:
    """Tạo JWT access token."""
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload = {"sub": str(subject), "exp": expire}
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> dict:
    """Giải mã JWT, ném JWTError nếu không hợp lệ."""
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])


def hash_reset_code(user_id: int, code: str) -> str:
    """HMAC-SHA256 (khoá SECRET_KEY) của mã 6 số đặt lại mật khẩu, gắn với user_id.

    Mã 6 số chỉ có 1 triệu khả năng: SHA-256 trần thì ai có bản sao DB cũng dò lại
    được mã trong tích tắc. Có khoá SECRET_KEY (không nằm trong DB) thì DB bị lộ
    một mình chưa đủ để dựng lại mã. Gắn user_id để cùng một mã của hai người
    cho ra hai hash khác nhau."""
    message = f"{user_id}:{code}".encode()
    return hmac.new(settings.SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()
