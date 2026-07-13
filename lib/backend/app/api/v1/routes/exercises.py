"""Endpoint công khai: danh sách bài tập đang active trong thư viện."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import exercise as exercise_crud
from app.schemas.exercise import ExerciseOut

router = APIRouter(tags=["exercises"])


@router.get("/exercises", response_model=list[ExerciseOut])
async def list_exercises(db: AsyncSession = Depends(get_db)) -> list[ExerciseOut]:
    """Thư viện bài tập đang mở (is_active=True) — dùng cho màn Exercises của app."""
    exercises = await exercise_crud.get_active_exercises(db)
    return [ExerciseOut.model_validate(e) for e in exercises]
