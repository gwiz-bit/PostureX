"""Test 2 job định kỳ của BE-13: nhắc nghỉ giải lao & tổng kết hằng ngày."""

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.crud.notification import (
    TYPE_BREAK,
    TYPE_DAILY_SUMMARY,
    get_notifications_by_user,
)
from app.models.user import User
from app.models.workout import Workout
from app.services.reminders import send_break_reminders, send_daily_summaries
from app.utils.timezone import vn_day_start_utc


def _add_workout(
    db: AsyncSession,
    user_id: int,
    *,
    reps: int = 10,
    accuracy: float = 90.0,
    created_at: datetime | None = None,
) -> None:
    now = datetime.now(timezone.utc)
    db.add(
        Workout(
            user_id=user_id,
            exercise="squat",
            total_reps=reps,
            duration_seconds=120,
            accuracy_score=accuracy,
            started_at=now,
            ended_at=now,
            created_at=created_at or now,
        )
    )


# --- Nhắc nghỉ giải lao -------------------------------------------------------


@pytest.mark.asyncio
async def test_break_reminder_goes_to_user_who_has_not_trained(
    seeded: dict, db_session: AsyncSession
) -> None:
    sent = await send_break_reminders(db_session)

    assert sent == 1
    notifications = await get_notifications_by_user(db_session, seeded["user"].id)
    assert notifications[0].type == TYPE_BREAK


@pytest.mark.asyncio
async def test_break_reminder_skips_user_who_already_trained_today(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Nhắc người vừa tập xong 'đứng dậy vận động đi' là vô duyên."""
    _add_workout(db_session, seeded["user"].id)
    await db_session.flush()

    sent = await send_break_reminders(db_session)

    assert sent == 0


@pytest.mark.asyncio
async def test_break_reminder_is_not_sent_twice_in_cooldown(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Chống trùng: uvicorn --reload khởi động lại không được bắn nhắc lần hai."""
    await send_break_reminders(db_session)
    sent_again = await send_break_reminders(db_session)

    assert sent_again == 0
    notifications = await get_notifications_by_user(db_session, seeded["user"].id)
    assert len(notifications) == 1


@pytest.mark.asyncio
async def test_break_reminder_skips_inactive_user(
    seeded: dict, db_session: AsyncSession
) -> None:
    seeded["user"].is_active = False
    await db_session.flush()

    sent = await send_break_reminders(db_session)

    assert sent == 0


# --- Tổng kết hằng ngày -------------------------------------------------------


@pytest.mark.asyncio
async def test_daily_summary_aggregates_todays_workouts(
    seeded: dict, db_session: AsyncSession
) -> None:
    _add_workout(db_session, seeded["user"].id, reps=10, accuracy=80.0)
    _add_workout(db_session, seeded["user"].id, reps=20, accuracy=90.0)
    await db_session.flush()

    sent = await send_daily_summaries(db_session)

    assert sent == 1
    body = (await get_notifications_by_user(db_session, seeded["user"].id))[0].body
    assert "2 buổi tập" in body
    assert "30 lần" in body
    assert "85%" in body  # trung bình của 80 và 90


@pytest.mark.asyncio
async def test_daily_summary_ignores_yesterdays_workouts(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Buổi tập hôm qua không được tính vào tổng kết hôm nay."""
    _add_workout(
        db_session,
        seeded["user"].id,
        created_at=vn_day_start_utc() - timedelta(minutes=1),
    )
    await db_session.flush()

    sent = await send_daily_summaries(db_session)

    assert sent == 0


@pytest.mark.asyncio
async def test_daily_summary_skips_user_with_no_workouts(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Không tập buổi nào thì im lặng — đã có 'nhắc nghỉ' rồi, đừng cằn nhằn thêm."""
    sent = await send_daily_summaries(db_session)

    assert sent == 0


@pytest.mark.asyncio
async def test_daily_summary_is_not_sent_twice_in_a_day(
    seeded: dict, db_session: AsyncSession
) -> None:
    _add_workout(db_session, seeded["user"].id)
    await db_session.flush()

    await send_daily_summaries(db_session)
    sent_again = await send_daily_summaries(db_session)

    assert sent_again == 0
    notifications = await get_notifications_by_user(db_session, seeded["user"].id)
    summaries = [n for n in notifications if n.type == TYPE_DAILY_SUMMARY]
    assert len(summaries) == 1


@pytest.mark.asyncio
async def test_daily_summary_only_targets_users_who_trained(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Người có tập thì nhận; người không tập thì không — kiểm với 2 user."""
    lazy = User(
        role_id=2,
        username="lazy",
        email="lazy@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True,
        is_active=True,
    )
    db_session.add(lazy)
    await db_session.flush()

    _add_workout(db_session, seeded["user"].id)
    await db_session.flush()

    sent = await send_daily_summaries(db_session)

    assert sent == 1
    assert await get_notifications_by_user(db_session, lazy.id) == []
