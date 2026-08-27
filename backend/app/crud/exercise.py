"""CRUD cho Exercise (thư viện bài tập)."""

from collections import defaultdict
from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise
from app.models.muscle_group import ExerciseMuscleGroup, MuscleGroup
from app.schemas.exercise import ExerciseCreate, ExerciseUpdate


async def get_active_exercises(db: AsyncSession) -> list[Exercise]:
    result = await db.execute(
        select(Exercise).where(Exercise.is_active == True).order_by(Exercise.name)  # noqa: E712
    )
    return list(result.scalars().all())


async def get_muscle_groups_by_exercise(
    db: AsyncSession, exercise_ids: Sequence[int]
) -> dict[int, list[str]]:
    """Map {exercise_id -> [tên nhóm cơ]} cho cả danh sách trong MỘT câu query.

    Gom một lượt thay vì để mỗi bài tự lazy-load: với 400+ bài, cách kia là
    400+ round-trip xuống MySQL chỉ để serialize một response.

    Nhóm cơ chính (`is_primary`) xếp trước để client muốn hiện đúng một nhãn
    thì lấy phần tử đầu là được.
    """
    if not exercise_ids:
        return {}

    result = await db.execute(
        select(ExerciseMuscleGroup.exercise_id, MuscleGroup.name)
        .join(MuscleGroup, MuscleGroup.id == ExerciseMuscleGroup.muscle_group_id)
        .where(ExerciseMuscleGroup.exercise_id.in_(exercise_ids))
        .order_by(ExerciseMuscleGroup.is_primary.desc(), MuscleGroup.name)
    )

    grouped: dict[int, list[str]] = defaultdict(list)
    for exercise_id, name in result.all():
        grouped[exercise_id].append(name)
    return dict(grouped)


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
