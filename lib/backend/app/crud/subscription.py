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
        # Mua gói thì mặc định muốn dùng tiếp — người dùng tự tắt nếu không muốn.
        # Cờ này KHÔNG tự thu tiền (VNPay không hỗ trợ), nó chỉ quyết định có nhắc
        # gia hạn khi sắp hết hạn hay không.
        auto_renew=True,
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

    **Gia hạn sớm được cộng dồn ngày còn lại.** Người dùng còn 10 ngày Premium mà
    gia hạn tiếp thì được 40 ngày, không phải 30 — nếu không, gia hạn sớm là tự
    ném đi số ngày đã trả tiền, và không ai dám bấm nút gia hạn trước khi hết hạn.

    Cộng dồn **chỉ áp dụng khi mua lại đúng gói cũ**. Đổi sang gói khác (Premium →
    Pro) thì tính lại từ đầu: quy đổi giá trị còn lại giữa hai gói khác giá là
    bài toán proration, cố tình không làm ở đây.
    """
    today = date.today()

    result = await db.execute(
        select(UserSubscription).where(
            UserSubscription.user_id == subscription.user_id,
            UserSubscription.status == SUBSCRIPTION_ACTIVE,
            UserSubscription.id != subscription.id,
        )
    )

    carried_over_days = 0
    for old in result.scalars().all():
        if (
            old.plan_id == subscription.plan_id
            and old.end_date is not None
            and old.end_date > today
        ):
            carried_over_days = max(carried_over_days, (old.end_date - today).days)

        old.status = SUBSCRIPTION_CANCELLED
        old.end_date = today

    payment.status = PAYMENT_PAID
    payment.transaction_no = transaction_no
    payment.gateway_log = gateway_log
    payment.paid_at = datetime.now(timezone.utc)

    subscription.status = SUBSCRIPTION_ACTIVE
    subscription.start_date = today
    subscription.end_date = today + timedelta(
        days=SUBSCRIPTION_PERIOD_DAYS + carried_over_days
    )

    await db.flush()


async def set_auto_renew(
    db: AsyncSession, subscription: UserSubscription, auto_renew: bool
) -> UserSubscription:
    """Bật/tắt tự động gia hạn.

    **Tắt (= "huỷ gói") KHÔNG cắt quyền ngay.** Người dùng đã trả tiền cho tới
    `EndDate`, nên gói vẫn Active tới ngày đó rồi mới tự hết hạn. Cắt ngay là ăn
    chặn số ngày họ đã mua.

    Cảnh báo cho người đọc sau: cờ này **không tự thu tiền được** — VNPay trong
    tích hợp hiện tại không hỗ trợ trừ tiền định kỳ. Nó chỉ dùng để quyết định có
    gửi thông báo nhắc gia hạn hay không (xem `services/reminders.py`).
    """
    subscription.auto_renew = auto_renew
    await db.flush()
    return subscription


async def list_payments(db: AsyncSession, user_id: int) -> list[Payment]:
    """Lịch sử thanh toán của user, mới nhất trước."""
    result = await db.execute(
        select(Payment)
        .join(UserSubscription, Payment.user_subscription_id == UserSubscription.id)
        .where(UserSubscription.user_id == user_id)
        .order_by(Payment.id.desc())
    )
    return list(result.scalars().all())


async def get_expiring_subscriptions(
    db: AsyncSession, within_days: int
) -> list[UserSubscription]:
    """Gói còn hiệu lực nhưng sắp hết hạn trong `within_days` ngày tới.

    Chỉ lấy gói **bật tự động gia hạn** — người đã chủ động tắt gia hạn thì họ
    biết rồi, nhắc nữa là làm phiền.
    """
    today = date.today()
    result = await db.execute(
        select(UserSubscription).where(
            UserSubscription.status == SUBSCRIPTION_ACTIVE,
            UserSubscription.auto_renew.is_(True),
            UserSubscription.end_date.is_not(None),
            UserSubscription.end_date >= today,
            UserSubscription.end_date <= today + timedelta(days=within_days),
        )
    )
    return list(result.scalars().all())
