"""Pydantic schemas cho Plan, PromoCode, Transaction, Notification."""

from datetime import datetime

from pydantic import BaseModel, Field


class PlanOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    tagline: str | None
    price_vnd: int
    duration_months: int
    features: str
    is_active: bool
    created_at: datetime


class PlanCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    tagline: str | None = None
    price_vnd: int = Field(ge=0)
    duration_months: int = Field(ge=0)
    features: str = ""
    is_active: bool = True


class PlanUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=50)
    tagline: str | None = None
    price_vnd: int | None = Field(default=None, ge=0)
    duration_months: int | None = Field(default=None, ge=0)
    features: str | None = None
    is_active: bool | None = None


class PromoCodeOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    code: str
    discount_percent: int
    expires_at: datetime | None
    is_active: bool
    created_at: datetime


class PromoCodeCreate(BaseModel):
    code: str = Field(min_length=1, max_length=30)
    discount_percent: int = Field(ge=1, le=100)
    expires_at: datetime | None = None
    is_active: bool = True


class PromoCodeUpdate(BaseModel):
    discount_percent: int | None = Field(default=None, ge=1, le=100)
    expires_at: datetime | None = None
    is_active: bool | None = None


class TransactionOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    user_id: int
    plan_id: int
    amount_vnd: int
    payment_method: str
    status: str
    created_at: datetime


class SubscribeRequest(BaseModel):
    plan_id: int
    promo_code: str | None = None


class RevenueStats(BaseModel):
    total_revenue_vnd: int
    total_transactions: int
    revenue_by_plan: dict[str, int]
    recent_transactions: list[TransactionOut]


class NotificationOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    title: str
    content: str
    audience: str
    created_at: datetime


class NotificationCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    audience: str = Field(default="all", pattern="^(all|premium|free)$")
