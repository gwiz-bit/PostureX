"""CRUD cho Plan, PromoCode, Transaction, Notification (subscription/revenue)."""

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import AUDIENCE_ALL, AUDIENCE_FREE, AUDIENCE_PREMIUM, Notification
from app.models.plan import Plan
from app.models.promo_code import PromoCode
from app.models.transaction import Transaction
from app.schemas.subscription import (
    NotificationCreate,
    PlanCreate,
    PlanUpdate,
    PromoCodeCreate,
    PromoCodeUpdate,
)

PREMIUM_PLAN_NAMES = {"Advanced", "Pro"}


# ---------------------------------------------------------------- Plans ----
async def get_active_plans(db: AsyncSession) -> list[Plan]:
    result = await db.execute(
        select(Plan).where(Plan.is_active == True).order_by(Plan.price_vnd)  # noqa: E712
    )
    return list(result.scalars().all())


async def get_all_plans(db: AsyncSession) -> list[Plan]:
    result = await db.execute(select(Plan).order_by(Plan.price_vnd))
    return list(result.scalars().all())


async def get_plan_by_id(db: AsyncSession, plan_id: int) -> Plan | None:
    return await db.get(Plan, plan_id)


async def create_plan(db: AsyncSession, data: PlanCreate) -> Plan:
    plan = Plan(**data.model_dump())
    db.add(plan)
    await db.flush()
    return plan


async def update_plan(db: AsyncSession, plan: Plan, data: PlanUpdate) -> Plan:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(plan, field, value)
    await db.flush()
    return plan


async def delete_plan(db: AsyncSession, plan: Plan) -> None:
    await db.delete(plan)
    await db.flush()


# ----------------------------------------------------------- PromoCodes ----
async def get_all_promo_codes(db: AsyncSession) -> list[PromoCode]:
    result = await db.execute(select(PromoCode).order_by(PromoCode.created_at.desc()))
    return list(result.scalars().all())


async def get_promo_by_id(db: AsyncSession, promo_id: int) -> PromoCode | None:
    return await db.get(PromoCode, promo_id)


async def get_valid_promo_by_code(db: AsyncSession, code: str) -> PromoCode | None:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(PromoCode).where(
            PromoCode.code == code,
            PromoCode.is_active == True,  # noqa: E712
        )
    )
    promo = result.scalar_one_or_none()
    if promo is None:
        return None
    if promo.expires_at is not None and promo.expires_at.replace(tzinfo=timezone.utc) < now:
        return None
    return promo


async def create_promo_code(db: AsyncSession, data: PromoCodeCreate) -> PromoCode:
    promo = PromoCode(**data.model_dump())
    db.add(promo)
    await db.flush()
    return promo


async def update_promo_code(db: AsyncSession, promo: PromoCode, data: PromoCodeUpdate) -> PromoCode:
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(promo, field, value)
    await db.flush()
    return promo


async def delete_promo_code(db: AsyncSession, promo: PromoCode) -> None:
    await db.delete(promo)
    await db.flush()


# ---------------------------------------------------------- Transactions ----
async def create_transaction(
    db: AsyncSession,
    user_id: int,
    plan: Plan,
    amount_vnd: int,
) -> Transaction:
    """Tạo giao dịch mock-payment, luôn thành công ngay lập tức."""
    tx = Transaction(
        user_id=user_id,
        plan_id=plan.id,
        amount_vnd=amount_vnd,
        payment_method="Mock Payment",
        status="success",
    )
    db.add(tx)
    await db.flush()
    return tx


async def get_latest_successful_transaction(db: AsyncSession, user_id: int) -> Transaction | None:
    """Giao dịch thành công gần nhất — dùng để suy ra 'gói hiện tại' của user."""
    result = await db.execute(
        select(Transaction)
        .where(Transaction.user_id == user_id, Transaction.status == "success")
        .order_by(Transaction.created_at.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def get_current_plan_for_user(db: AsyncSession, user_id: int) -> Plan | None:
    tx = await get_latest_successful_transaction(db, user_id)
    if tx is None:
        return None
    return await db.get(Plan, tx.plan_id)


async def is_user_premium(db: AsyncSession, user_id: int) -> bool:
    plan = await get_current_plan_for_user(db, user_id)
    return plan is not None and plan.name in PREMIUM_PLAN_NAMES


async def get_revenue_stats(db: AsyncSession, recent_limit: int = 20) -> dict:
    total_revenue = (
        await db.execute(
            select(func.coalesce(func.sum(Transaction.amount_vnd), 0)).where(
                Transaction.status == "success"
            )
        )
    ).scalar_one()
    total_transactions = (
        await db.execute(
            select(func.count()).select_from(Transaction).where(Transaction.status == "success")
        )
    ).scalar_one()

    by_plan_rows = (
        await db.execute(
            select(Plan.name, func.coalesce(func.sum(Transaction.amount_vnd), 0))
            .join(Transaction, Transaction.plan_id == Plan.id)
            .where(Transaction.status == "success")
            .group_by(Plan.name)
        )
    ).all()
    revenue_by_plan = {name: int(total) for name, total in by_plan_rows}

    recent = (
        await db.execute(
            select(Transaction).order_by(Transaction.created_at.desc()).limit(recent_limit)
        )
    ).scalars().all()

    return {
        "total_revenue_vnd": int(total_revenue),
        "total_transactions": total_transactions,
        "revenue_by_plan": revenue_by_plan,
        "recent_transactions": list(recent),
    }


# --------------------------------------------------------- Notifications ----
async def get_all_notifications(db: AsyncSession) -> list[Notification]:
    result = await db.execute(select(Notification).order_by(Notification.created_at.desc()))
    return list(result.scalars().all())


async def create_notification(db: AsyncSession, data: NotificationCreate) -> Notification:
    notif = Notification(**data.model_dump())
    db.add(notif)
    await db.flush()
    return notif


async def get_notifications_for_user(db: AsyncSession, user_id: int) -> list[Notification]:
    """Thông báo dành cho user, lọc theo audience khớp gói hiện tại (suy ra
    từ giao dịch gần nhất) — 'all' luôn hiển thị cho mọi user."""
    premium = await is_user_premium(db, user_id)
    audience_match = AUDIENCE_PREMIUM if premium else AUDIENCE_FREE
    result = await db.execute(
        select(Notification)
        .where(Notification.audience.in_([AUDIENCE_ALL, audience_match]))
        .order_by(Notification.created_at.desc())
    )
    return list(result.scalars().all())
