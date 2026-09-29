"""Pydantic schemas cho WorkoutSessions API."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class RepOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    rep_number: int
    is_clean: bool
    form_score: float | None
    peak_angle: float | None
    range_of_motion: float | None
    recorded_at: datetime


class FeedbackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    feedback_type: str
    message: str | None
    channel: str | None
    elapsed_ms: int | None
    occurred_at: datetime


class SessionExerciseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    exercise_id: int
    total_reps: int
    clean_reps: int
    form_score: float | None
    duration_sec: int | None
    reps: list[RepOut] = []
    feedback: list[FeedbackOut] = []


class SessionListItemOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    started_at: datetime
    ended_at: datetime | None
    status: str
    total_duration_sec: int | None
    overall_form_score: float | None


class SessionDetailOut(SessionListItemOut):
    exercises: list[SessionExerciseOut] = []
