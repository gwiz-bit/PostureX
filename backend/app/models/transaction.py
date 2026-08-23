"""Model bảng Transactions — lịch sử thanh toán subscription.

Không có cổng thanh toán thật (Stripe/VNPay...) nối vào — mỗi giao dịch
được tạo bởi POST /subscriptions/subscribe với payment_method="Mock
Payment" và status="success" ngay lập tức. Đây là điểm cần thay bằng
tích hợp cổng thanh toán thật trước khi lên production.

"Gói hiện tại" của 1 user được suy ra từ giao dịch thành công gần nhất
của họ (xem crud/subscription.py) — không có bảng Subscriptions/expiry
riêng vì không có billing chu kỳ thật để hết hạn/gia hạn.
"""

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.plan import Plan
    from app.models.user import User


class Transaction(Base):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    plan_id: Mapped[int] = mapped_column(ForeignKey("plans.id"), nullable=False, index=True)
    amount_vnd: Mapped[int] = mapped_column(Integer, nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), default="Mock Payment")
    status: Mapped[str] = mapped_column(String(20), default="success")
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )

    user: Mapped["User"] = relationship("User")
    plan: Mapped["Plan"] = relationship("Plan")
