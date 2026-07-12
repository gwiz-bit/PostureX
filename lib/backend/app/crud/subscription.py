"""CRUD cho gói cước & thanh toán."""

from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.subscription import (
    PAYMENT_FAILED,
    PAYMENT_PAID,
    PAYMENT_PENDING,
    SUBSCRIPTION_ACTIVE,
    SUBSCRIPTION_CANCELLED,
    SUBSCRIPTION_EXPIRED,
    SUBSCRIPTION_UNPAID,
    Payment,
    SubscriptionPlan,
    UserSubscription,
)

# Một chu kỳ = 1 tháng. Dùng 30 ngày cho đơn giản và ổn định (không phải xử lý
# chuyện 31/1 + 1 tháng ra ngày nào).
SUBSCRIPTION_PERIOD_DAYS = 30


async def list_active_plans(db: AsyncSession) -> list[SubscriptionPlan]:
    result = await db.execute(
        select(SubscriptionPlan)
        .where(SubscriptionPlan.is_active.is_(True))
        .order_by(SubscriptionPlan.price_monthly)
    )
    return list(result.scalars().all())


async def get_plan_by_id(db: AsyncSession, plan_id: int) -> SubscriptionPlan | None:
    result = await db.execute(
        select(SubscriptionPlan).where(SubscriptionPlan.id == plan_id)
    )
    return result.scalar_one_or_none()


async def get_active_subscription(db: AsyncSession, user_id: int) -> UserSubscription | None:
    """Gói CÒN HIỆU LỰC của user, hoặc None.

    Không hệ thống nào quét gói quá hạn (không có cron job), nên hàm này tự lật
    gói đã qua `EndDate` sang 'Expired' ngay lúc đọc. Nếu chỉ lọc theo Status thì
    trả tiền một lần là dùng Premium vĩnh viễn.

    Duyệt mới nhất trước, phòng khi dữ liệu cũ có nhiều dòng Active (schema không
    có ràng buộc chặn điều đó).
    """
    today = date.today()
    result = await db.execute(
        select(UserSubscription)
        .where(
            UserSubscription.user_id == user_id,
            UserSubscription.status == SUBSCRIPTION_ACTIVE,
        )
        .order_by(UserSubscription.id.desc())
    )

    current: UserSubscription | None = None
    for subscription in result.scalars().all():
        if subscription.end_date is not None and subscription.end_date < today:
            subscription.status = SUBSCRIPTION_EXPIRED
        elif current is None:
            # EndDate NULL = dữ liệu cũ không ghi hạn. Coi như còn hiệu lực chứ
            # không tự ý tắt gói của người ta.
            current = subscription

    await db.flush()
    return current


async def is_premium(db: AsyncSession, user_id: int) -> bool:
    """User có đang dùng gói TRẢ PHÍ còn hiệu lực không.

    Không chỉ hỏi "có gói Active không": một dòng Active trỏ tới gói Free (giá 0)
    thì vẫn là người dùng miễn phí, không được mở khoá gì.
    """
    subscription = await get_active_subscription(db, user_id)
    if subscription is None:
        return False

    plan = await get_plan_by_id(db, subscription.plan_id)
    return plan is not None and plan.price_monthly > 0


async def create_pending_order(
    db: AsyncSession, user_id: int, plan: SubscriptionPlan
) -> tuple[UserSubscription, Payment]:
    """Tạo đơn chờ thanh toán: UserSubscription(Pending) + Payment(Pending).

    `Payment.id` chính là `vnp_TxnRef` gửi sang VNPay — nên phải flush để lấy id
    trước khi dựng URL thanh toán.
    """
    subscription = UserSubscription(
        user_id=user_id,
        plan_id=plan.id,
        start_date=date.today(),
        end_date=None,
        # Chưa trả tiền thì chưa có hiệu lực. Schema không cho 'Pending' ở bảng
        # này (xem CK_UserSub_Status), nên dùng 'Cancelled' làm trạng thái chờ.
        status=SUBSCRIPTION_UNPAID,
        auto_renew=False,
    )
    db.add(subscription)
    await db.flush()

    payment = Payment(
        user_subscription_id=subscription.id,
        amount=plan.price_monthly,
        currency=plan.currency,
        payment_method="VNPAY",
        status=PAYMENT_PENDING,
    )
    db.add(payment)
    await db.flush()

    return subscription, payment


async def get_payment_by_id(db: AsyncSession, payment_id: int) -> Payment | None:
    result = await db.execute(select(Payment).where(Payment.id == payment_id))
    return result.scalar_one_or_none()


async def get_subscription_by_id(
    db: AsyncSession, subscription_id: int
) -> UserSubscription | None:
    result = await db.execute(
        select(UserSubscription).where(UserSubscription.id == subscription_id)
    )
    return result.scalar_one_or_none()


async def mark_payment_failed(db: AsyncSession, payment: Payment, gateway_log: str) -> None:
    payment.status = PAYMENT_FAILED
    payment.gateway_log = gateway_log
    await db.flush()


async def activate_subscription(
    db: AsyncSession,
    payment: Payment,
    subscription: UserSubscription,
    transaction_no: str | None,
    gateway_log: str,
) -> None:
    """Ghi nhận thanh toán thành công và kích hoạt gói.

    Huỷ mọi gói Active cũ của user trước khi bật gói mới — schema không có ràng
    buộc nào chặn một user có 2 gói Active cùng lúc, nên phải tự bảo đảm.
    """
    result = await db.execute(
        select(UserSubscription).where(
            UserSubscription.user_id == subscription.user_id,
            UserSubscription.status == SUBSCRIPTION_ACTIVE,
            UserSubscription.id != subscription.id,
        )
    )
    for old in result.scalars().all():
        old.status = SUBSCRIPTION_CANCELLED
        old.end_date = date.today()

    payment.status = PAYMENT_PAID
    payment.transaction_no = transaction_no
    payment.gateway_log = gateway_log
    payment.paid_at = datetime.now(timezone.utc)

    subscription.status = SUBSCRIPTION_ACTIVE
    subscription.start_date = date.today()
    subscription.end_date = date.today() + timedelta(days=SUBSCRIPTION_PERIOD_DAYS)

    await db.flush()
