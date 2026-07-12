"""Test gói cước: hết hạn, quyền Premium, giới hạn buổi tập của gói Free."""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.subscription import get_active_subscription, is_premium
from app.models.subscription import (
    SUBSCRIPTION_ACTIVE,
    SUBSCRIPTION_EXPIRED,
    UserSubscription,
)

TODAY = date.today()


def _subscribe(db: AsyncSession, user_id: int, plan_id: int, end_date: date | None) -> None:
    db.add(
        UserSubscription(
            user_id=user_id,
            plan_id=plan_id,
            start_date=TODAY - timedelta(days=30),
            end_date=end_date,
            status=SUBSCRIPTION_ACTIVE,
            auto_renew=False,
        )
    )


@pytest.mark.asyncio
async def test_plans_endpoint_hides_inactive_plans(client: AsyncClient, seeded: dict) -> None:
    resp = await client.get("/api/v1/subscriptions/plans")

    assert resp.status_code == 200
    names = [p["name"] for p in resp.json()]
    assert names == ["Free", "Premium"]  # sắp theo giá tăng dần, bỏ gói IsActive=0


@pytest.mark.asyncio
async def test_no_subscription_returns_null(client: AsyncClient, auth: dict) -> None:
    resp = await client.get("/api/v1/subscriptions/me", headers=auth)

    assert resp.status_code == 200
    assert resp.json() is None


@pytest.mark.asyncio
async def test_valid_subscription_is_returned(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, TODAY + timedelta(days=10))
    await db_session.commit()

    resp = await client.get("/api/v1/subscriptions/me", headers=auth)

    assert resp.status_code == 200
    assert resp.json()["plan_name"] == "Premium"


@pytest.mark.asyncio
async def test_expired_subscription_is_not_active_anymore(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """BUG-1: gói quá EndDate phải hết hiệu lực, dù Status trong DB vẫn là 'Active'."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, TODAY - timedelta(days=1))
    await db_session.commit()

    resp = await client.get("/api/v1/subscriptions/me", headers=auth)

    assert resp.status_code == 200
    assert resp.json() is None


@pytest.mark.asyncio
async def test_expired_subscription_is_flipped_to_expired_in_db(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """...và dòng dữ liệu được dọn luôn, không để 'Active' vĩnh viễn."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, TODAY - timedelta(days=1))
    await db_session.commit()

    await client.get("/api/v1/subscriptions/me", headers=auth)

    subscription = await db_session.get(UserSubscription, 1)
    assert subscription.status == SUBSCRIPTION_EXPIRED


@pytest.mark.asyncio
async def test_subscription_valid_on_its_last_day(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Hết hạn HÔM NAY vẫn còn dùng được — không cắt sớm một ngày của khách."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, TODAY)
    await db_session.commit()

    assert await get_active_subscription(db_session, seeded["user"].id) is not None


@pytest.mark.asyncio
async def test_active_free_plan_is_not_premium(seeded: dict, db_session: AsyncSession) -> None:
    """Dòng Active trỏ vào gói giá 0 không mở khoá gì cả."""
    _subscribe(db_session, seeded["user"].id, seeded["free"].id, TODAY + timedelta(days=10))
    await db_session.commit()

    assert await is_premium(db_session, seeded["user"].id) is False


@pytest.mark.asyncio
async def test_checkout_rejects_free_plan(client: AsyncClient, auth: dict, seeded: dict) -> None:
    resp = await client.post(
        "/api/v1/subscriptions/checkout", headers=auth, json={"plan_id": seeded["free"].id}
    )

    # 400 nếu VNPay đã cấu hình; 503 nếu chưa. Cả hai đều là "không tạo đơn 0đ".
    assert resp.status_code in (400, 503)


@pytest.mark.asyncio
async def test_my_subscription_requires_auth(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/subscriptions/me")

    assert resp.status_code == 403  # HTTPBearer trả 403 khi thiếu header
