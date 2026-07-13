"""Xử lý JWT và hash mật khẩu."""

import hashlib
from datetime import datetime, timedelta, timezone
from typing import Any

from jose import JWTError, jwt
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


def hash_reset_token(raw_token: str) -> str:
    """SHA-256 hex digest của raw token đặt lại mật khẩu — dùng để lưu/so
    khớp trong DB mà không bao giờ lưu token gốc (không dùng bcrypt như mật
    khẩu vì token đã có entropy cao sẵn từ secrets.token_urlsafe, không cần
    salt/cost factor — chỉ cần 1 hash nhanh, xác định để tra cứu bằng
    index)."""
    return hashlib.sha256(raw_token.encode()).hexdigest()
