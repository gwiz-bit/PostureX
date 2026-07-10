"""Endpoints lịch sử buổi tập."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.user import User
from app.models.workout import Workout
from app.utils.deps import get_current_user

router = APIRouter(prefix="/workouts", tags=["workouts"])


class WorkoutCreate(BaseModel):
    exercise: str
    total_reps: int = 0
    duration_seconds: float | None = None
    accuracy_score: float | None = None
    started_at: datetime


class WorkoutOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    exercise: str
    total_reps: int
    duration_seconds: float | None
    accuracy_score: float | None
    started_at: datetime
    ended_at: datetime | None
    created_at: datetime


@router.post("", response_model=WorkoutOut, status_code=status.HTTP_201_CREATED)
async def create_workout(
    data: WorkoutCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> WorkoutOut:
    """Lưu một buổi tập vào lịch sử."""
    workout = Workout(
        user_id=current_user.id,
        exercise=data.exercise,
        total_reps=data.total_reps,
        duration_seconds=data.duration_seconds,
        accuracy_score=data.accuracy_score,
        started_at=data.started_at,
        ended_at=datetime.now(timezone.utc),
    )
    db.add(workout)
    await db.flush()
    return WorkoutOut.model_validate(workout)


@router.get("", response_model=list[WorkoutOut])
async def list_workouts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[WorkoutOut]:
    """Lấy lịch sử buổi tập của user hiện tại, mới nhất trước."""
    result = await db.execute(
        select(Workout)
        .where(Workout.user_id == current_user.id)
        .order_by(Workout.created_at.desc())
    )
    workouts = result.scalars().all()
    return [WorkoutOut.model_validate(w) for w in workouts]


@router.get("/{workout_id}", response_model=WorkoutOut)
async def get_workout(
    workout_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> WorkoutOut:
    """Lấy chi tiết một buổi tập."""
    result = await db.execute(
        select(Workout).where(Workout.id == workout_id, Workout.user_id == current_user.id)
    )
    workout = result.scalar_one_or_none()
    if workout is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy buổi tập.")
    return WorkoutOut.model_validate(workout)
