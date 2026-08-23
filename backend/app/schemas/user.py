"""Pydantic schemas cho User."""

from datetime import datetime

from pydantic import BaseModel, EmailStr, field_validator

from app.schemas.validators import validate_password_strength


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None


class UserUpdate(BaseModel):
    """User tự chỉnh sửa hồ sơ cá nhân."""
    full_name: str | None = None
    password: str | None = None

    @field_validator("password")
    @classmethod
    def _validate_strength(cls, v: str | None) -> str | None:
        if v is None:
            return v
        return validate_password_strength(v)


class UserOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    email: str
    full_name: str | None
    is_active: bool
    is_admin: bool
    created_at: datetime
