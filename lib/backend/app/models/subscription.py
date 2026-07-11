"""Model 3 bảng gói cước & thanh toán: SubscriptionPlans, UserSubscriptions, Payments.

Cả 3 đều thuộc schema PostureX của nhóm (sql/postureX123_schema.sql) — cột đặt
tên PascalCase, và **không** do create_tables.py quản lý. Tuyệt đối không thêm
chúng vào DROP_SQL của create_tables.py.
"""

from datetime import date, datetime, timezone
from decimal import Decimal

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

# Giá trị cột Status — bị ràng buộc CỨNG bởi CHECK constraint trong schema của
# nhóm (sql/postureX123_schema.sql). Ghi giá trị ngoài danh sách này, MySQL sẽ
# ném lỗi 3819 "Check constraint is violated":
#
#   CK_UserSub_Status  CHECK (Status IN ('Active', 'Expired', 'Cancelled'))
#   CK_Payments_Status CHECK (Status IN ('Pending', 'Completed', 'Failed', 'Refunded'))
#
# Lưu ý: bảng UserSubscriptions KHÔNG có trạng thái 'Pending'. Nên đơn chờ thanh
# toán được ghi tạm là 'Cancelled' (chưa có hiệu lực, và sẽ đúng nghĩa luôn nếu
# người dùng bỏ ngang) rồi mới lật sang 'Active' khi trả tiền xong.
# → Nếu muốn sạch hơn, cần người thiết kế DB thêm 'Pending' vào CK_UserSub_Status.
SUBSCRIPTION_ACTIVE = "Active"
SUBSCRIPTION_CANCELLED = "Cancelled"
SUBSCRIPTION_UNPAID = SUBSCRIPTION_CANCELLED

PAYMENT_PENDING = "Pending"
PAYMENT_PAID = "Completed"
PAYMENT_FAILED = "Failed"


class SubscriptionPlan(Base):
    __tablename__ = "SubscriptionPlans"

    id: Mapped[int] = mapped_column("SubscriptionPlanId", primary_key=True)
    name: Mapped[str] = mapped_column("Name", String(50), unique=True, nullable=False)
    price_monthly: Mapped[Decimal] = mapped_column("PriceMonthly", Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column("Currency", String(10), nullable=False)
    features: Mapped[str | None] = mapped_column("Features", String(1000), nullable=True)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, nullable=False, default=True)


class UserSubscription(Base):
    __tablename__ = "UserSubscriptions"

    id: Mapped[int] = mapped_column("UserSubscriptionId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId"), nullable=False, index=True
    )
    plan_id: Mapped[int] = mapped_column(
        "SubscriptionPlanId",
        ForeignKey("SubscriptionPlans.SubscriptionPlanId"),
        nullable=False,
    )
    start_date: Mapped[date] = mapped_column("StartDate", Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column("EndDate", Date, nullable=True)
    status: Mapped[str] = mapped_column("Status", String(20), nullable=False)
    auto_renew: Mapped[bool] = mapped_column("AutoRenew", Boolean, nullable=False, default=False)


class Payment(Base):
    __tablename__ = "Payments"

    id: Mapped[int] = mapped_column("PaymentId", primary_key=True)
    user_subscription_id: Mapped[int] = mapped_column(
        "UserSubscriptionId",
        ForeignKey("UserSubscriptions.UserSubscriptionId"),
        nullable=False,
        index=True,
    )
    # Mã giao dịch bên cổng thanh toán trả về (vnp_TransactionNo).
    transaction_no: Mapped[str | None] = mapped_column("TransactionNo", String(100), nullable=True)
    amount: Mapped[Decimal] = mapped_column("Amount", Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column("Currency", String(10), nullable=False)
    payment_method: Mapped[str] = mapped_column("PaymentMethod", String(50), nullable=False)
    status: Mapped[str] = mapped_column("Status", String(20), nullable=False, index=True)
    # Lưu nguyên query string VNPay trả về, để đối soát khi có tranh chấp.
    gateway_log: Mapped[str | None] = mapped_column("PaymentGatewayLog", Text, nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column("PaidAt", DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, default=lambda: datetime.now(timezone.utc), nullable=False
    )
