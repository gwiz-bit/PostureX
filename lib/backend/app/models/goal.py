"""Model bảng Goals — mục tiêu cá nhân (ví dụ số buổi tập/tuần từ onboarding)."""

from datetime import date
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Date, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User

WORKOUTS_PER_WEEK_GOAL_TYPE = "WorkoutsPerWeek"


class Goal(Base):
    __tablename__ = "Goals"

    id: Mapped[int] = mapped_column("GoalId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    goal_type: Mapped[str] = mapped_column("GoalType", String(40), nullable=False)
    target_value: Mapped[float] = mapped_column("TargetValue", Numeric(10, 2), nullable=False)
    current_value: Mapped[float] = mapped_column("CurrentValue", Numeric(10, 2), default=0)
    start_date: Mapped[date] = mapped_column("StartDate", Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column("EndDate", Date, nullable=True)
    is_achieved: Mapped[bool] = mapped_column("IsAchieved", Boolean, default=False)

    user: Mapped["User"] = relationship("User")
