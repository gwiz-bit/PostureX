"""Models PlanWorkoutDays và PlanScheduledSessions — lịch tập thực tế.

PlanWorkoutDays: ngày trong tuần user chọn tập (câu 14 onboarding).
PlanScheduledSessions: buổi tập đã lên kế hoạch cụ thể theo ngày/tuần.

Bản gốc chỉ có WorkoutPlans (tĩnh) và WorkoutSessions (đã tập xong).
Hai bảng này lấp khoảng trống "buổi thứ 3 tuần 2, dự kiến thứ Sáu".
"""

from __future__ import annotations

from datetime import date

from sqlalchemy import Date, ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class PlanWorkoutDay(Base):
    """Ngày trong tuần user muốn tập — 1=Thứ Hai, 7=Chủ Nhật."""

    __tablename__ = "PlanWorkoutDays"

    plan_id: Mapped[int] = mapped_column(
        "PlanId", ForeignKey("WorkoutPlans.PlanId", ondelete="CASCADE"), primary_key=True
    )
    day_of_week: Mapped[int] = mapped_column("DayOfWeek", SmallInteger, primary_key=True)
    reminder_enabled: Mapped[int] = mapped_column("ReminderEnabled", SmallInteger, nullable=False, default=1)


class PlanScheduledSession(Base):
    """Buổi tập đã lên kế hoạch — từng buổi theo ngày cụ thể."""

    __tablename__ = "PlanScheduledSessions"

    id: Mapped[int] = mapped_column("ScheduledSessionId", primary_key=True)
    plan_id: Mapped[int] = mapped_column(
        "PlanId", ForeignKey("WorkoutPlans.PlanId", ondelete="CASCADE"), nullable=False, index=True
    )
    template_session_id: Mapped[int] = mapped_column(
        "TemplateSessionId", ForeignKey("TemplateSessions.TemplateSessionId"), nullable=False
    )
    week_no: Mapped[int] = mapped_column("WeekNo", SmallInteger, nullable=False)
    scheduled_date: Mapped[date] = mapped_column("ScheduledDate", Date, nullable=False)
    status: Mapped[str] = mapped_column(
        "Status", String(20), nullable=False, default="Planned"
    )  # Planned / Done / Skipped
