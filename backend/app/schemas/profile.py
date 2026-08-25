"""Pydantic schemas cho hồ sơ thể chất (UserProfiles + Goal) từ onboarding."""

from pydantic import BaseModel, Field


class ProfileUpdate(BaseModel):
    age: int | None = Field(default=None, ge=1, le=120)
    gender: str | None = Field(default=None, pattern="^(Male|Female|Other)$")
    # Bounds mirror the Flutter app's own picker ranges (only client that
    # calls this route today) — see lib/models/profile_limits.dart. Kept
    # here too since the backend can't trust the client not to send
    # garbage (negative/zero/absurdly large values) directly to the API.
    height_cm: float | None = Field(default=None, ge=140, le=220)
    weight_kg: float | None = Field(default=None, ge=35, le=180)
    fitness_level: str | None = Field(
        default=None, pattern="^(Beginner|Intermediate|Advanced)$"
    )
    # Mirrors lib/models/onboarding_options.dart's workoutsPerWeek range.
    weekly_goal: int | None = Field(default=None, ge=1, le=7)


class ProfileOut(BaseModel):
    age: int | None
    gender: str | None
    height_cm: float | None
    weight_kg: float | None
    fitness_level: str | None
    weekly_goal: int | None
