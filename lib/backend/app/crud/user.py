"""CRUD operations cho bảng Users."""

import re
import secrets

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.crud.role import get_role_by_name
from app.models.role import USER_ROLE_NAME
from app.models.user import User
from app.schemas.user import UserCreate


async def get_user_by_email(db: AsyncSession, email: str) -> User | None:
    """Tìm user theo email."""
    result = await db.execute(select(User).where(User.email == email))
    return result.scalar_one_or_none()


async def get_user_by_id(db: AsyncSession, user_id: int) -> User | None:
    """Tìm user theo ID."""
    result = await db.execute(select(User).where(User.id == user_id))
    return result.scalar_one_or_none()


async def generate_unique_username(db: AsyncSession, email: str) -> str:
    """Sinh Username duy nhất từ phần trước @ của email — schema Users yêu
    cầu Username NOT NULL UNIQUE nhưng API đăng ký của app chỉ nhận
    email/password/full_name, không thu thập username riêng."""
    base = re.sub(r"[^a-zA-Z0-9_]", "", email.split("@", 1)[0]).lower() or "user"
    candidate = base
    suffix = 1
    while (await db.execute(select(User.id).where(User.username == candidate))).scalar_one_or_none():
        suffix += 1
        candidate = f"{base}{suffix}"
    return candidate


async def create_user(db: AsyncSession, data: UserCreate) -> User:
    """Tạo user mới (role mặc định 'User'), trả về object đã flush."""
    role = await get_role_by_name(db, USER_ROLE_NAME)
    if role is None:
        raise RuntimeError(
            "Role 'User' chưa tồn tại trong bảng Roles — chạy sql/run_schema.py trước."
        )
    user = User(
        email=data.email,
        username=await generate_unique_username(db, data.email),
        hashed_password=hash_password(data.password),
        full_name=data.full_name,
        role=role,  # gán trực tiếp object đã nạp, tránh phải lazy-load lại role_id
    )
    db.add(user)
    await db.flush()   # lấy id trước khi commit
    return user


async def create_google_user(db: AsyncSession, *, email: str, full_name: str | None) -> User:
    """Tạo user từ tài khoản Google đã xác thực — email của Google luôn coi
    là đã xác thực (is_email_verified=True ngay), và mật khẩu được sinh
    ngẫu nhiên (schema Users yêu cầu PasswordHash NOT NULL) — người dùng
    không biết mật khẩu này và không cần dùng đến vì luôn đăng nhập lại
    bằng Google."""
    role = await get_role_by_name(db, USER_ROLE_NAME)
    if role is None:
        raise RuntimeError(
            "Role 'User' chưa tồn tại trong bảng Roles — chạy sql/run_schema.py trước."
        )
    user = User(
        email=email,
        username=await generate_unique_username(db, email),
        hashed_password=hash_password(secrets.token_urlsafe(32)),
        full_name=full_name,
        is_email_verified=True,
        role=role,
    )
    db.add(user)
    await db.flush()
    return user
