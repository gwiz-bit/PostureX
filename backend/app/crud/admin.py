"""CRUD operations dành riêng cho Admin."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.role import get_role_by_name
from app.models.role import ADMIN_ROLE_NAME, USER_ROLE_NAME, Role
from app.models.user import User
from app.models.video import Video
from app.models.workout import Workout
from app.schemas.admin import AdminUserUpdate


async def get_all_users(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 50,
) -> list[User]:
    """Lấy danh sách tất cả user, mới nhất trước."""
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).offset(skip).limit(limit)
    )
    return list(result.scalars().all())


async def update_user_by_admin(
    db: AsyncSession,
    user: User,
    data: AdminUserUpdate,
) -> User:
    """Admin cập nhật thông tin user (active, role, tên)."""
    if data.full_name is not None:
        user.full_name = data.full_name
    if data.is_active is not None:
        user.is_active = data.is_active
    if data.is_admin is not None:
        role_name = ADMIN_ROLE_NAME if data.is_admin else USER_ROLE_NAME
        role = await get_role_by_name(db, role_name)
        if role is None:
            raise RuntimeError(f"Role '{role_name}' chưa tồn tại trong bảng Roles.")
        user.role = role
    await db.flush()
    return user


async def delete_user(db: AsyncSession, user: User) -> None:
    """Xóa user và toàn bộ dữ liệu liên quan (cascade qua ORM)."""
    await db.delete(user)
    await db.flush()


async def get_all_workouts(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 50,
) -> list[Workout]:
    """Lấy tất cả workout của mọi user."""
    result = await db.execute(
        select(Workout).order_by(Workout.created_at.desc()).offset(skip).limit(limit)
    )
    return list(result.scalars().all())


async def delete_workout(db: AsyncSession, workout: Workout) -> None:
    """Xóa một buổi tập."""
    await db.delete(workout)
    await db.flush()


async def get_system_stats(db: AsyncSession) -> dict:
    """Tổng hợp thống kê toàn hệ thống."""
    total_users = (await db.execute(select(func.count()).select_from(User))).scalar_one()
    active_users = (await db.execute(
        select(func.count()).select_from(User).where(User.is_active == True)  # noqa: E712
    )).scalar_one()
    admin_users = (await db.execute(
        select(func.count()).select_from(User).where(User.role.has(Role.name == ADMIN_ROLE_NAME))
    )).scalar_one()
    total_videos = (await db.execute(select(func.count()).select_from(Video))).scalar_one()
    total_workouts = (await db.execute(select(func.count()).select_from(Workout))).scalar_one()
    total_reps = (await db.execute(
        select(func.coalesce(func.sum(Workout.total_reps), 0)).select_from(Workout)
    )).scalar_one()

    return {
        "total_users": total_users,
        "active_users": active_users,
        "admin_users": admin_users,
        "total_videos": total_videos,
        "total_workouts": total_workouts,
        "total_reps": int(total_reps),
    }
