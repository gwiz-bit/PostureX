"""Pydantic schemas cho hồ sơ thể chất (UserProfiles + Goal) từ onboarding."""

from pydantic import BaseModel, Field


class ProfileUpdate(BaseModel):
    gender: str | None = Field(default=None, pattern="^(Male|Female|Other)$")
    height_cm: float | None = None
    weight_kg: float | None = None
    fitness_level: str | None = Field(
        default=None, pattern="^(Beginner|Intermediate|Advanced)$"
    )
    weekly_goal: int | None = None


class ProfileOut(BaseModel):
    gender: str | None
    height_cm: float | None
    weight_kg: float | None
    fitness_level: str | None
    weekly_goal: int | None
