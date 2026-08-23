"""Pydantic schemas cho Video."""

from datetime import datetime

from pydantic import BaseModel


class VideoOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    user_id: int
    exercise: str
    original_filename: str | None
    duration_seconds: float | None
    total_reps: int
    accuracy_score: float | None
    analysis_summary: str | None
    created_at: datetime
