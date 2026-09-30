"""Models bảng WorkoutPlans và WorkoutPlanExercises (schema PostureX v2).

Khác với WorkoutPlan trong Dart (client-only, sinh thuần client):
  - Bảng này lưu lịch tập do backend/AI tạo ra, bao gồm cả plan từ POST /coach/plan.
  - Khi user áp lịch từ AI Coach, có thể tạo một WorkoutPlan hàng trong DB này.

Thay đổi v2 so với v1:
  WorkoutPlans: PlanName → Name; thêm ProgramCode FK, Goal, EquipmentTier,
    VolumeMultiplier, CurrentWeek, Status (thay IsActive), DurationDays (thay
    DurationWeeks+DaysPerWeek), IsSystemPlan (thay IsAiGenerated), GeneratedAt;
    bỏ DifficultyLevel, EndDate.
  WorkoutPlanExercises: thêm ScheduledSessionId FK, SlotId FK,
    SubstitutedFromExerciseId, SubstitutionReason, WeekNo (thay WeekNumber),
    DayNumber, OrderIndex (thay OrderInSession), TargetSets (thay Sets),
    TargetReps (thay RepsPerSet), TargetRepsText, TargetDurationSec (thay
    DurationSec), RestSeconds (thay RestSec), IsAccessory; bỏ WeightKg, Notes.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Integer, Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class WorkoutPlanDB(Base):
    """Lịch tập được lưu trong DB — do AI hoặc admin tạo."""

    __tablename__ = "WorkoutPlans"

    id: Mapped[int] = mapped_column("PlanId", primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        "UserId", ForeignKey("Users.UserId"), nullable=True, index=True
    )
    program_code: Mapped[str | None] = mapped_column(
        "ProgramCode", String(3), ForeignKey("ProgramTemplates.ProgramCode"), nullable=True
    )
    name: Mapped[str] = mapped_column("Name", String(120), nullable=False)
    description: Mapped[str | None] = mapped_column("Description", String(1000), nullable=True)
    goal: Mapped[str | None] = mapped_column("Goal", String(50), nullable=True)
    equipment_tier: Mapped[str | None] = mapped_column("EquipmentTier", String(2), nullable=True)
    volume_multiplier: Mapped[Decimal] = mapped_column(
        "VolumeMultiplier", Numeric(3, 2), nullable=False, default=Decimal("1.00")
    )
    current_week: Mapped[int] = mapped_column("CurrentWeek", SmallInteger, nullable=False, default=1)
    status: Mapped[str] = mapped_column("Status", String(20), nullable=False, default="Active")
    duration_days: Mapped[int | None] = mapped_column("DurationDays", Integer, nullable=True)
    is_system_plan: Mapped[int] = mapped_column("IsSystemPlan", SmallInteger, nullable=False, default=0)
    start_date: Mapped[date | None] = mapped_column("StartDate", Date, nullable=True)
    generated_at: Mapped[datetime | None] = mapped_column("GeneratedAt", DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )

    plan_exercises: Mapped[list[WorkoutPlanExercise]] = relationship(
        "WorkoutPlanExercise", back_populates="plan", cascade="all, delete-orphan"
    )


class WorkoutPlanExercise(Base):
    """Một bài tập đã chốt trong lịch tập — không join ngược SlotDefaultExercises."""

    __tablename__ = "WorkoutPlanExercises"

    id: Mapped[int] = mapped_column("PlanExerciseId", primary_key=True)
    plan_id: Mapped[int] = mapped_column(
        "PlanId", ForeignKey("WorkoutPlans.PlanId", ondelete="CASCADE"), nullable=False, index=True
    )
    scheduled_session_id: Mapped[int | None] = mapped_column(
        "ScheduledSessionId",
        ForeignKey("PlanScheduledSessions.ScheduledSessionId", ondelete="CASCADE"),
        nullable=True,
    )
    slot_id: Mapped[int | None] = mapped_column(
        "SlotId", ForeignKey("TemplateSlots.SlotId"), nullable=True
    )
    exercise_id: Mapped[int] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId"), nullable=False
    )
    substituted_from_exercise_id: Mapped[int | None] = mapped_column(
        "SubstitutedFromExerciseId", ForeignKey("Exercises.ExerciseId"), nullable=True
    )
    substitution_reason: Mapped[str | None] = mapped_column("SubstitutionReason", String(20), nullable=True)
    week_no: Mapped[int | None] = mapped_column("WeekNo", SmallInteger, nullable=True)
    day_number: Mapped[int | None] = mapped_column("DayNumber", Integer, nullable=True)
    order_index: Mapped[int | None] = mapped_column("OrderIndex", Integer, nullable=True)
    target_sets: Mapped[int | None] = mapped_column("TargetSets", Integer, nullable=True)
    target_reps: Mapped[int | None] = mapped_column("TargetReps", Integer, nullable=True)
    target_reps_text: Mapped[str | None] = mapped_column("TargetRepsText", String(30), nullable=True)
    target_duration_sec: Mapped[int | None] = mapped_column("TargetDurationSec", Integer, nullable=True)
    rest_seconds: Mapped[int | None] = mapped_column("RestSeconds", Integer, nullable=True)
    is_accessory: Mapped[int] = mapped_column("IsAccessory", SmallInteger, nullable=False, default=0)

    plan: Mapped[WorkoutPlanDB] = relationship("WorkoutPlanDB", back_populates="plan_exercises")
