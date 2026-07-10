"""CRUD cho UserProfiles + Goal (mục tiêu số buổi tập/tuần) từ onboarding."""

from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import WORKOUTS_PER_WEEK_GOAL_TYPE, Goal
from app.models.user_profile import UserProfile
from app.schemas.profile import ProfileOut, ProfileUpdate


async def get_profile(db: AsyncSession, user_id: int) -> ProfileOut:
    """Lấy hồ sơ thể chất + mục tiêu hiện tại của user (rỗng nếu chưa lưu)."""
    profile = await db.get(UserProfile, user_id)
    goal = await _get_weekly_goal(db, user_id)
    return ProfileOut(
        gender=profile.gender if profile else None,
        height_cm=float(profile.height_cm) if profile and profile.height_cm is not None else None,
        weight_kg=float(profile.weight_kg) if profile and profile.weight_kg is not None else None,
        fitness_level=profile.fitness_level if profile else None,
        weekly_goal=int(goal.target_value) if goal else None,
    )


async def upsert_profile(db: AsyncSession, user_id: int, data: ProfileUpdate) -> ProfileOut:
    """Tạo mới hoặc cập nhật UserProfiles + Goal WorkoutsPerWeek cho user."""
    profile = await db.get(UserProfile, user_id)
    if profile is None:
        profile = UserProfile(user_id=user_id)
        db.add(profile)

    if data.gender is not None:
        profile.gender = data.gender
    if data.height_cm is not None:
        profile.height_cm = data.height_cm
    if data.weight_kg is not None:
        profile.weight_kg = data.weight_kg
    if data.fitness_level is not None:
        profile.fitness_level = data.fitness_level

    if data.weekly_goal is not None:
        goal = await _get_weekly_goal(db, user_id)
        if goal is None:
            goal = Goal(
                user_id=user_id,
                goal_type=WORKOUTS_PER_WEEK_GOAL_TYPE,
                target_value=data.weekly_goal,
                start_date=date.today(),
            )
            db.add(goal)
        else:
            goal.target_value = data.weekly_goal

    await db.flush()
    return await get_profile(db, user_id)


async def _get_weekly_goal(db: AsyncSession, user_id: int) -> Goal | None:
    result = await db.execute(
        select(Goal)
        .where(Goal.user_id == user_id, Goal.goal_type == WORKOUTS_PER_WEEK_GOAL_TYPE)
        .order_by(Goal.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()
