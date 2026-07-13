"""Model bảng UserProfiles (1-1 với Users) — hồ sơ thể chất từ onboarding."""

from datetime import date, datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class UserProfile(Base):
    __tablename__ = "UserProfiles"

    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), primary_key=True
    )
    date_of_birth: Mapped[date | None] = mapped_column("DateOfBirth", Date, nullable=True)
    gender: Mapped[str | None] = mapped_column("Gender", String(10), nullable=True)
    height_cm: Mapped[float | None] = mapped_column("HeightCm", Numeric(5, 2), nullable=True)
    weight_kg: Mapped[float | None] = mapped_column("WeightKg", Numeric(5, 2), nullable=True)
    fitness_level: Mapped[str | None] = mapped_column("FitnessLevel", String(20), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        "UpdatedAt", DateTime, default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User")
