"""Schema Pydantic cho gói cước & thanh toán."""

from datetime import date
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


class CheckoutIn(BaseModel):
    plan_id: int


class CheckoutOut(BaseModel):
    payment_id: int
    pay_url: str
