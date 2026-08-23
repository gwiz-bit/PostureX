"""CRUD operations cho bảng Roles."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Role


async def get_role_by_name(db: AsyncSession, name: str) -> Role | None:
    """Tìm role theo tên (Admin/User)."""
    result = await db.execute(select(Role).where(Role.name == name))
    return result.scalar_one_or_none()
