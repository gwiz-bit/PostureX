"""CRUD cho Exercise (thư viện bài tập)."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise
from app.schemas.exercise import ExerciseCreate, ExerciseUpdate


async def get_active_exercises(db: AsyncSession) -> list[Exercise]:
    result = await db.execute(
        select(Exercise).where(Exercise.is_active == True).order_by(Exercise.name)  # noqa: E712
    )
    return list(result.scalars().all())


async def get_all_exercises(db: AsyncSession) -> list[Exercise]:
    result = await db.execute(select(Exercise).order_by(Exercise.name))
    return list(result.scalars().all())


async def get_exercise_by_id(db: AsyncSession, exercise_id: int) -> Exercise | None:
    return await db.get(Exercise, exercise_id)


async def create_exercise(db: AsyncSession, data: ExerciseCreate) -> Exercise:
    exercise = Exercise(**data.model_dump())
    db.add(exercise)
    await db.flush()
    return exercise


async def update_exercise(db: AsyncSession, exercise: Exercise, data: ExerciseUpdate) -> Exercise:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(exercise, field, value)
    await db.flush()
    return exercise


async def delete_exercise(db: AsyncSession, exercise: Exercise) -> None:
    await db.delete(exercise)
    await db.flush()
