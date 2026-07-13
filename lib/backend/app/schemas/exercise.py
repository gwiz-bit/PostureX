"""Pydantic schemas cho Exercise (thư viện bài tập)."""

from datetime import datetime

from pydantic import BaseModel, Field


class ExerciseOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    description: str | None
    category: str | None
    difficulty: str | None
    exercise_type: str
    demo_video_url: str | None
    thumbnail_url: str | None
    met: float | None
    is_active: bool
    created_at: datetime


class ExerciseCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = None
    category: str | None = Field(default=None, max_length=50)
    difficulty: str | None = Field(default=None, pattern="^(Beginner|Intermediate|Advanced)$")
    exercise_type: str = Field(default="Standard", pattern="^(Standard|Duration)$")
    demo_video_url: str | None = None
    thumbnail_url: str | None = None
    met: float | None = None
    is_active: bool = True


class ExerciseUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = None
    category: str | None = Field(default=None, max_length=50)
    difficulty: str | None = Field(default=None, pattern="^(Beginner|Intermediate|Advanced)$")
    exercise_type: str | None = Field(default=None, pattern="^(Standard|Duration)$")
    demo_video_url: str | None = None
    thumbnail_url: str | None = None
    met: float | None = None
    is_active: bool | None = None
