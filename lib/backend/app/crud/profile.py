"""CRUD cho UserProfiles + Goal (mục tiêu số buổi tập/tuần) từ onboarding."""

from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.goal import WORKOUTS_PER_WEEK_GOAL_TYPE, Goal
from app.models.user_profile import UserProfile
from app.schemas.profile import ProfileOut, ProfileUpdate


def _age_from_dob(dob: date | None) -> int | None:
    """UserProfiles lưu DateOfBirth (đúng chuẩn), nhưng app chỉ thu thập
    "tuổi" dạng số nguyên lúc onboarding — quy đổi 2 chiều ở tầng CRUD để
    API vẫn nhận/trả về `age` đơn giản cho client."""
    if dob is None:
        return None
    today = date.today()
    years = today.year - dob.year
    if (today.month, today.day) < (dob.month, dob.day):
        years -= 1
    return years


def _dob_from_age(age: int) -> date:
    """Sinh 1 DateOfBirth hợp lệ tương ứng với `age` hiện tại (giữ nguyên
    tháng/ngày hôm nay — luôn hợp lệ vì lấy từ date.today() của chính năm
    đó, không có rủi ro 29/2 rơi vào năm không nhuận)."""
    today = date.today()
    return date(today.year - age, today.month, today.day)


async def get_profile(db: AsyncSession, user_id: int) -> ProfileOut:
    """Lấy hồ sơ thể chất + mục tiêu hiện tại của user (rỗng nếu chưa lưu)."""
    profile = await db.get(UserProfile, user_id)
    goal = await _get_weekly_goal(db, user_id)
    return ProfileOut(
        age=_age_from_dob(profile.date_of_birth) if profile else None,
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

    if data.age is not None:
        profile.date_of_birth = _dob_from_age(data.age)
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
