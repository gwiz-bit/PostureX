"""Test BUG-2 (giới hạn buổi tập của gói Free) và BUG-3 (thông báo tự sinh)."""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.workouts import FREE_DAILY_WORKOUT_LIMIT
from app.models.subscription import SUBSCRIPTION_ACTIVE, UserSubscription

WORKOUT = {
    "exercise": "squat",
    "total_reps": 10,
    "duration_seconds": 120,
    "accuracy_score": 88,
    "started_at": "2026-07-12T10:00:00Z",
}


def _give_premium(db: AsyncSession, user_id: int, plan_id: int) -> None:
    db.add(
        UserSubscription(
            user_id=user_id,
            plan_id=plan_id,
            start_date=date.today(),
            end_date=date.today() + timedelta(days=30),
            status=SUBSCRIPTION_ACTIVE,
            auto_renew=False,
        )
    )


@pytest.mark.asyncio
async def test_free_user_can_save_up_to_the_daily_limit(
    client: AsyncClient, auth: dict, seeded: dict
) -> None:
    for _ in range(FREE_DAILY_WORKOUT_LIMIT):
        resp = await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)
        assert resp.status_code == 201


@pytest.mark.asyncio
async def test_free_user_is_blocked_past_the_daily_limit(
    client: AsyncClient, auth: dict, seeded: dict
) -> None:
    """BUG-2: gói Free hứa 'giới hạn 3 bài tập/ngày' — trước đây không ai thực thi."""
    for _ in range(FREE_DAILY_WORKOUT_LIMIT):
        await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)

    resp = await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)

    assert resp.status_code == 403
    assert "Premium" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_premium_user_is_not_blocked(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """Thứ khách trả tiền để mua: không bị chặn. Fix mà thiếu test này thì vô nghĩa."""
    _give_premium(db_session, seeded["user"].id, seeded["premium"].id)
    await db_session.commit()

    for _ in range(FREE_DAILY_WORKOUT_LIMIT + 2):
        resp = await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)
        assert resp.status_code == 201


@pytest.mark.asyncio
async def test_expired_premium_falls_back_to_free_limit(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """Gói hết hạn → quay lại hạn mức Free. Nối BUG-1 với BUG-2."""
    db_session.add(
        UserSubscription(
            user_id=seeded["user"].id,
            plan_id=seeded["premium"].id,
            start_date=date.today() - timedelta(days=60),
            end_date=date.today() - timedelta(days=1),
            status=SUBSCRIPTION_ACTIVE,
            auto_renew=False,
        )
    )
    await db_session.commit()

    for _ in range(FREE_DAILY_WORKOUT_LIMIT):
        await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)
    resp = await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)

    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_saving_a_workout_creates_a_notification(
    client: AsyncClient, auth: dict, seeded: dict
) -> None:
    """BUG-3: trước đây chỉ thanh toán mới sinh thông báo."""
    await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)

    resp = await client.get("/api/v1/notifications", headers=auth)

    assert resp.status_code == 200
    notifications = resp.json()
    assert len(notifications) == 1
    assert notifications[0]["type"] == "workout"
    assert "squat" in notifications[0]["body"]


@pytest.mark.asyncio
async def test_blocked_workout_creates_no_notification(
    client: AsyncClient, auth: dict, seeded: dict
) -> None:
    """Buổi tập bị chặn thì không được lưu, cũng không được báo là đã xong."""
    for _ in range(FREE_DAILY_WORKOUT_LIMIT + 1):
        await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)

    resp = await client.get("/api/v1/notifications", headers=auth)

    assert len(resp.json()) == FREE_DAILY_WORKOUT_LIMIT
