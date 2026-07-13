"""Test quản lý gói cước (BE-14): huỷ, bật lại, gia hạn cộng dồn, nhắc hết hạn."""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.notification import (
    TYPE_SUBSCRIPTION,
    TYPE_SUBSCRIPTION_EXPIRY,
    get_notifications_by_user,
)
from app.crud.subscription import (
    SUBSCRIPTION_PERIOD_DAYS,
    activate_subscription,
    create_pending_order,
    get_active_subscription,
    is_premium,
)
from app.models.subscription import (
    PAYMENT_PENDING,
    SUBSCRIPTION_ACTIVE,
    Payment,
    UserSubscription,
)
from app.services.reminders import send_expiry_reminders

TODAY = date.today()


def _subscribe(
    db: AsyncSession,
    user_id: int,
    plan_id: int,
    *,
    days_left: int = 20,
    auto_renew: bool = True,
) -> UserSubscription:
    subscription = UserSubscription(
        user_id=user_id,
        plan_id=plan_id,
        start_date=TODAY - timedelta(days=10),
        end_date=TODAY + timedelta(days=days_left),
        status=SUBSCRIPTION_ACTIVE,
        auto_renew=auto_renew,
    )
    db.add(subscription)
    return subscription


# --- Huỷ / bật lại gia hạn ----------------------------------------------------


@pytest.mark.asyncio
async def test_cancel_keeps_premium_until_end_date(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """Huỷ gói KHÔNG được cắt quyền ngay — khách đã trả tiền cho những ngày đó."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=20)
    await db_session.commit()

    resp = await client.post("/api/v1/subscriptions/cancel", headers=auth)

    assert resp.status_code == 200
    assert resp.json()["auto_renew"] is False
    assert resp.json()["status"] == SUBSCRIPTION_ACTIVE
    assert resp.json()["days_left"] == 20
    # Quyền Premium vẫn còn nguyên.
    assert await is_premium(db_session, seeded["user"].id) is True


@pytest.mark.asyncio
async def test_cancel_notifies_the_user(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id)
    await db_session.commit()

    await client.post("/api/v1/subscriptions/cancel", headers=auth)

    notifications = await get_notifications_by_user(db_session, seeded["user"].id)
    assert notifications[0].type == TYPE_SUBSCRIPTION
    assert "huỷ" in notifications[0].title.lower()


@pytest.mark.asyncio
async def test_cancel_twice_is_rejected(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, auto_renew=False)
    await db_session.commit()

    resp = await client.post("/api/v1/subscriptions/cancel", headers=auth)

    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_cancel_without_a_subscription_is_404(
    client: AsyncClient, auth: dict, seeded: dict
) -> None:
    resp = await client.post("/api/v1/subscriptions/cancel", headers=auth)

    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_resume_turns_auto_renew_back_on(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, auto_renew=False)
    await db_session.commit()

    resp = await client.post("/api/v1/subscriptions/resume", headers=auth)

    assert resp.status_code == 200
    assert resp.json()["auto_renew"] is True


# --- Gia hạn: cộng dồn ngày còn lại -------------------------------------------


async def _pay_for(
    db: AsyncSession, user_id: int, plan
) -> UserSubscription:
    """Mua gói `plan` và thanh toán thành công."""
    subscription, payment = await create_pending_order(db, user_id, plan)
    await activate_subscription(
        db, payment=payment, subscription=subscription, transaction_no="X", gateway_log=""
    )
    return subscription


@pytest.mark.asyncio
async def test_renewing_early_carries_over_remaining_days(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Còn 10 ngày mà gia hạn tiếp → được 40 ngày, không phải 30.

    Không cộng dồn thì gia hạn sớm là tự ném đi số ngày đã trả tiền, và không ai
    dám bấm nút gia hạn trước khi hết hạn.
    """
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=10)
    await db_session.flush()

    renewed = await _pay_for(db_session, seeded["user"].id, seeded["premium"])

    assert renewed.end_date == TODAY + timedelta(days=SUBSCRIPTION_PERIOD_DAYS + 10)


@pytest.mark.asyncio
async def test_switching_plan_does_not_carry_over_days(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Đổi sang gói khác thì tính lại từ đầu — proration cố tình không làm."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=10)
    await db_session.flush()

    hidden = seeded["hidden"]  # gói khác, giá khác
    switched = await _pay_for(db_session, seeded["user"].id, hidden)

    assert switched.end_date == TODAY + timedelta(days=SUBSCRIPTION_PERIOD_DAYS)


@pytest.mark.asyncio
async def test_first_purchase_gets_exactly_one_period(
    seeded: dict, db_session: AsyncSession
) -> None:
    subscription = await _pay_for(db_session, seeded["user"].id, seeded["premium"])

    assert subscription.end_date == TODAY + timedelta(days=SUBSCRIPTION_PERIOD_DAYS)
    assert subscription.auto_renew is True  # mua gói thì mặc định muốn dùng tiếp


@pytest.mark.asyncio
async def test_only_one_active_subscription_after_renewal(
    seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=10)
    await db_session.flush()

    await _pay_for(db_session, seeded["user"].id, seeded["premium"])

    current = await get_active_subscription(db_session, seeded["user"].id)
    assert current is not None
    assert current.end_date == TODAY + timedelta(days=SUBSCRIPTION_PERIOD_DAYS + 10)


# --- Nhắc sắp hết hạn ---------------------------------------------------------


@pytest.mark.asyncio
async def test_expiry_reminder_for_subscription_ending_soon(
    seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=2)
    await db_session.flush()

    sent = await send_expiry_reminders(db_session)

    assert sent == 1
    notification = (await get_notifications_by_user(db_session, seeded["user"].id))[0]
    assert notification.type == TYPE_SUBSCRIPTION_EXPIRY
    assert "sắp hết hạn" in notification.title


@pytest.mark.asyncio
async def test_no_expiry_reminder_when_far_from_expiry(
    seeded: dict, db_session: AsyncSession
) -> None:
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=20)
    await db_session.flush()

    assert await send_expiry_reminders(db_session) == 0


@pytest.mark.asyncio
async def test_no_expiry_reminder_when_user_already_cancelled(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Đã tự tắt gia hạn thì họ biết rồi — nhắc nữa là làm phiền."""
    _subscribe(
        db_session, seeded["user"].id, seeded["premium"].id, days_left=2, auto_renew=False
    )
    await db_session.flush()

    assert await send_expiry_reminders(db_session) == 0


@pytest.mark.asyncio
async def test_expiry_reminder_is_not_repeated(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Cửa sổ cảnh báo là 3 ngày — không được nhắc 3 ngày liên tiếp."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=2)
    await db_session.flush()

    await send_expiry_reminders(db_session)
    assert await send_expiry_reminders(db_session) == 0


@pytest.mark.asyncio
async def test_cancel_then_resume_still_gets_expiry_reminder(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """Bug thật, bắt được khi chạy trên MySQL: thông báo "đã huỷ gia hạn" từng
    dùng chung nhãn với lời nhắc hết hạn, nên nó **nuốt** luôn lời nhắc của cả
    tuần sau đó. Người dùng đổi ý bật lại gia hạn sẽ không bao giờ được nhắc."""
    _subscribe(db_session, seeded["user"].id, seeded["premium"].id, days_left=2)
    await db_session.commit()

    await client.post("/api/v1/subscriptions/cancel", headers=auth)
    await client.post("/api/v1/subscriptions/resume", headers=auth)

    assert await send_expiry_reminders(db_session) == 1


# --- Lịch sử thanh toán -------------------------------------------------------


@pytest.mark.asyncio
async def test_payment_history_lists_own_payments(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    subscription = _subscribe(db_session, seeded["user"].id, seeded["premium"].id)
    await db_session.flush()
    db_session.add(
        Payment(
            user_subscription_id=subscription.id,
            amount=Decimal("99000.00"),
            currency="VND",
            payment_method="MOMO",
            status=PAYMENT_PENDING,
        )
    )
    await db_session.commit()

    resp = await client.get("/api/v1/payments", headers=auth)

    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["payment_method"] == "MOMO"
