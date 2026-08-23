"""Schema Pydantic cho gói cước & thanh toán."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel


class PlanOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    price_monthly: Decimal
    currency: str
    features: str | None


class MySubscriptionOut(BaseModel):
    """Gói đang dùng. `plan_name` phẳng hoá để client khỏi gọi thêm một lượt."""

    id: int
    plan_id: int
    plan_name: str
    status: str
    start_date: date
    end_date: date | None
    # False = người dùng đã huỷ gia hạn; gói vẫn chạy tới end_date rồi tự tắt.
    auto_renew: bool
    # Số ngày còn lại, để app khỏi phải tự tính (và tính sai múi giờ).
    days_left: int | None


class CheckoutIn(BaseModel):
    plan_id: int


class CheckoutOut(BaseModel):
    payment_id: int
    pay_url: str


class PaymentOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    amount: Decimal
    currency: str
    payment_method: str
    status: str
    paid_at: datetime | None
    created_at: datetime
