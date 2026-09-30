"""CRUD helpers cho WorkoutSessions, SessionExercises, SessionReps, RealtimeFeedback.

Được dùng bởi routes/realtime.py để lưu lịch sử buổi tập theo thời gian thực,
và bởi routes/sessions.py để đọc lịch sử.
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.session import RealtimeFeedback, SessionExercise, SessionRep, WorkoutSession


async def create_workout_session(
    db: AsyncSession,
    *,
    user_id: int,
    started_at: datetime | None = None,
) -> WorkoutSession:
    session = WorkoutSession(
        user_id=user_id,
        started_at=started_at or datetime.now(timezone.utc),
        status="InProgress",
    )
    db.add(session)
    await db.flush()  # lấy id ngay, commit do caller quyết định
    return session


async def get_or_create_session_exercise(
    db: AsyncSession,
    *,
    session_id: int,
    exercise_id: int,
) -> SessionExercise:
    """Trả về SessionExercise đã có cho bài đó trong phiên này, hoặc tạo mới."""
    result = await db.execute(
        select(SessionExercise).where(
            SessionExercise.session_id == session_id,
            SessionExercise.exercise_id == exercise_id,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        return existing
    se = SessionExercise(session_id=session_id, exercise_id=exercise_id, total_reps=0, clean_reps=0)
    db.add(se)
    await db.flush()
    return se


async def record_rep(
    db: AsyncSession,
    *,
    session_exercise_id: int,
    rep_number: int,
    is_clean: bool = True,
    form_score: float | None = None,
    peak_angle: float | None = None,
    range_of_motion: float | None = None,
) -> SessionRep:
    """Tạo một hàng SessionRep và tăng counter trên SessionExercise."""
    rep = SessionRep(
        session_exercise_id=session_exercise_id,
        rep_number=rep_number,
        is_clean=is_clean,
        form_score=form_score,
        peak_angle=peak_angle,
        range_of_motion=range_of_motion,
    )
    db.add(rep)

    # cập nhật tổng rep trên SessionExercise
    await db.execute(
        update(SessionExercise)
        .where(SessionExercise.id == session_exercise_id)
        .values(
            total_reps=SessionExercise.total_reps + 1,
            clean_reps=SessionExercise.clean_reps + (1 if is_clean else 0),
        )
        .execution_options(synchronize_session=False)
    )
    await db.flush()
    return rep


async def record_feedback(
    db: AsyncSession,
    *,
    session_exercise_id: int,
    rep_id: int | None = None,
    message: str,
    feedback_type: str = "Error",
    channel: str | None = None,
    elapsed_ms: int | None = None,
) -> RealtimeFeedback:
    fb = RealtimeFeedback(
        session_exercise_id=session_exercise_id,
        rep_id=rep_id,
        message=message,
        feedback_type=feedback_type,
        channel=channel,
        elapsed_ms=elapsed_ms,
    )
    db.add(fb)
    await db.flush()
    return fb


async def finalize_session(
    db: AsyncSession,
    *,
    session_id: int,
    ended_at: datetime | None = None,
    overall_form_score: float | None = None,
    status: str = "Completed",
) -> None:
    """Đánh dấu phiên tập kết thúc và ghi điểm tổng."""
    end = ended_at or datetime.now(timezone.utc)
    result = await db.execute(
        select(WorkoutSession).where(WorkoutSession.id == session_id)
    )
    session = result.scalar_one_or_none()
    if session is None:
        return
    duration = int((end - session.started_at).total_seconds())
    await db.execute(
        update(WorkoutSession)
        .where(WorkoutSession.id == session_id)
        .values(
            ended_at=end,
            status=status,
            total_duration_sec=duration,
            overall_form_score=overall_form_score,
        )
        .execution_options(synchronize_session=False)
    )
    await db.commit()


# ── Read helpers ────────────────────────────────────────────────────────────


async def list_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    limit: int = 20,
    offset: int = 0,
) -> list[WorkoutSession]:
    result = await db.execute(
        select(WorkoutSession)
        .where(WorkoutSession.user_id == user_id)
        .order_by(WorkoutSession.started_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return list(result.scalars().all())


async def get_session_detail(
    db: AsyncSession,
    *,
    session_id: int,
    user_id: int,
) -> WorkoutSession | None:
    result = await db.execute(
        select(WorkoutSession)
        .where(WorkoutSession.id == session_id, WorkoutSession.user_id == user_id)
        .options(
            selectinload(WorkoutSession.exercises).selectinload(SessionExercise.reps),
            selectinload(WorkoutSession.exercises).selectinload(SessionExercise.feedback),
        )
    )
    return result.scalar_one_or_none()
