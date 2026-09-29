"""Models bảng WorkoutSessions, SessionExercises, SessionReps, RealtimeFeedback.

Đây là bốn bảng lõi lưu lịch sử buổi tập theo từng rep/lỗi, thuộc schema
PostureX (sql/postureX123_schema.sql). Trước 29/09/2026 backend tính toán
dữ liệu này trong realtime.py nhưng vứt đi — các bảng này được wire vào
realtime.py từ ngày đó để tự động ghi lịch sử.

Thay đổi v2: WorkoutSession thêm scheduled_session_id FK → PlanScheduledSessions;
SessionExercise thêm plan_exercise_id FK → WorkoutPlanExercises.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import BigInteger, DateTime, ForeignKey, Integer, Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class WorkoutSession(Base):
    """Một buổi tập — bắt đầu khi WebSocket mở, kết thúc khi ngắt kết nối."""

    __tablename__ = "WorkoutSessions"

    id: Mapped[int] = mapped_column("SessionId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    plan_id: Mapped[int | None] = mapped_column(
        "PlanId", ForeignKey("WorkoutPlans.PlanId"), nullable=True
    )
    scheduled_session_id: Mapped[int | None] = mapped_column(
        "ScheduledSessionId",
        ForeignKey("PlanScheduledSessions.ScheduledSessionId"),
        nullable=True,
    )
    device_id: Mapped[int | None] = mapped_column(
        "DeviceId", ForeignKey("Devices.DeviceId"), nullable=True
    )
    started_at: Mapped[datetime] = mapped_column(
        "StartedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    ended_at: Mapped[datetime | None] = mapped_column("EndedAt", DateTime, nullable=True)
    status: Mapped[str] = mapped_column(
        "Status", String(20), nullable=False, default="InProgress"
    )  # InProgress / Completed / Discarded
    total_duration_sec: Mapped[int | None] = mapped_column("TotalDurationSec", Integer, nullable=True)
    calories_burned: Mapped[float | None] = mapped_column("CaloriesBurned", Numeric(7, 2), nullable=True)
    overall_form_score: Mapped[float | None] = mapped_column(
        "OverallFormScore", Numeric(5, 2), nullable=True
    )
    notes: Mapped[str | None] = mapped_column("Notes", String(500), nullable=True)

    exercises: Mapped[list[SessionExercise]] = relationship(
        "SessionExercise", back_populates="session", cascade="all, delete-orphan"
    )


class SessionExercise(Base):
    """Một bài tập trong buổi — mỗi bài khác nhau tạo một hàng riêng."""

    __tablename__ = "SessionExercises"

    id: Mapped[int] = mapped_column("SessionExerciseId", primary_key=True)
    session_id: Mapped[int] = mapped_column(
        "SessionId", ForeignKey("WorkoutSessions.SessionId", ondelete="CASCADE"), nullable=False, index=True
    )
    exercise_id: Mapped[int] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId"), nullable=False
    )
    plan_exercise_id: Mapped[int | None] = mapped_column(
        "PlanExerciseId",
        ForeignKey("WorkoutPlanExercises.PlanExerciseId"),
        nullable=True,
    )
    order_index: Mapped[int | None] = mapped_column("OrderIndex", Integer, nullable=True)
    total_reps: Mapped[int] = mapped_column("TotalReps", Integer, nullable=False, default=0)
    clean_reps: Mapped[int] = mapped_column("CleanReps", Integer, nullable=False, default=0)
    duration_sec: Mapped[int | None] = mapped_column("DurationSec", Integer, nullable=True)
    form_score: Mapped[float | None] = mapped_column("FormScore", Numeric(5, 2), nullable=True)
    weight_kg: Mapped[float | None] = mapped_column("WeightKg", Numeric(6, 2), nullable=True)

    session: Mapped[WorkoutSession] = relationship("WorkoutSession", back_populates="exercises")
    reps: Mapped[list[SessionRep]] = relationship(
        "SessionRep", back_populates="session_exercise", cascade="all, delete-orphan"
    )
    feedback: Mapped[list[RealtimeFeedback]] = relationship(
        "RealtimeFeedback", back_populates="session_exercise", cascade="all, delete-orphan"
    )


class SessionRep(Base):
    """Chi tiết một rep đã hoàn thành."""

    __tablename__ = "SessionReps"

    id: Mapped[int] = mapped_column("RepId", BigInteger, primary_key=True)
    session_exercise_id: Mapped[int] = mapped_column(
        "SessionExerciseId",
        ForeignKey("SessionExercises.SessionExerciseId", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    rep_number: Mapped[int] = mapped_column("RepNumber", Integer, nullable=False)
    is_clean: Mapped[bool] = mapped_column("IsClean", SmallInteger, nullable=False, default=1)
    form_score: Mapped[float | None] = mapped_column("FormScore", Numeric(5, 2), nullable=True)
    peak_angle: Mapped[float | None] = mapped_column("PeakAngle", Numeric(5, 2), nullable=True)
    range_of_motion: Mapped[float | None] = mapped_column("RangeOfMotion", Numeric(5, 2), nullable=True)
    tempo_sec: Mapped[float | None] = mapped_column("TempoSec", Numeric(5, 2), nullable=True)
    recorded_at: Mapped[datetime] = mapped_column(
        "RecordedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )

    session_exercise: Mapped[SessionExercise] = relationship("SessionExercise", back_populates="reps")


class RealtimeFeedback(Base):
    """Một lỗi/cảnh báo được phát hiện trong frame — gắn với rep nào (nếu biết)."""

    __tablename__ = "RealtimeFeedback"

    id: Mapped[int] = mapped_column("FeedbackId", BigInteger, primary_key=True)
    session_exercise_id: Mapped[int] = mapped_column(
        "SessionExerciseId",
        ForeignKey("SessionExercises.SessionExerciseId", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # Không tạo FK → SessionReps / PostureErrorTypes ở đây để tránh phụ thuộc
    # vòng tại thời điểm INSERT (rep_id được gán SAU khi tạo SessionRep).
    # Tham chiếu được ghi ở tầng ứng dụng, không phải ORM constraint.
    rep_id: Mapped[int | None] = mapped_column("RepId", BigInteger, nullable=True)
    error_type_id: Mapped[int | None] = mapped_column("ErrorTypeId", Integer, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        "OccurredAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    elapsed_ms: Mapped[int | None] = mapped_column("ElapsedMs", Integer, nullable=True)
    feedback_type: Mapped[str] = mapped_column(
        "FeedbackType", String(20), nullable=False, default="Error"
    )  # Error / Warning / Correction / Praise
    measured_angle: Mapped[float | None] = mapped_column("MeasuredAngle", Numeric(5, 2), nullable=True)
    deviation_degrees: Mapped[float | None] = mapped_column(
        "DeviationDegrees", Numeric(5, 2), nullable=True
    )
    channel: Mapped[str | None] = mapped_column("Channel", String(20), nullable=True)
    message: Mapped[str | None] = mapped_column("Message", String(500), nullable=True)

    session_exercise: Mapped[SessionExercise] = relationship(
        "SessionExercise", back_populates="feedback"
    )
