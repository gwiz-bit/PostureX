"""Pydantic schemas dành riêng cho Admin."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class AdminUserUpdate(BaseModel):
    """Admin cập nhật thông tin bất kỳ user."""
    full_name: str | None = None
    is_active: bool | None = None
    is_admin: bool | None = None


class AdminUserOut(BaseModel):
    """Thông tin user đầy đủ chỉ admin mới thấy."""
    model_config = {"from_attributes": True}

    id: int
    email: str
    full_name: str | None
    is_active: bool
    is_admin: bool
    created_at: datetime


class SystemStats(BaseModel):
    """Thống kê toàn hệ thống."""
    total_users: int
    active_users: int
    admin_users: int
    total_videos: int
    total_workouts: int
    total_reps: int


class AIConfig(BaseModel):
    """Cấu hình ngưỡng phân tích AI cho từng bài tập."""
    squat_knee_depth_threshold: float = 95.0
    squat_back_straight_min: float = 150.0
    squat_knee_overshoot_ratio: float = 0.05
    squat_rep_down_threshold: float = 95.0
    squat_rep_up_threshold: float = 160.0
    pose_model_complexity: int = 1
    pose_min_detection_confidence: float = 0.5


# ─────────────────────────────────────────────
# Quản lý gói cước (SubscriptionPlans) — admin
# ─────────────────────────────────────────────

class AdminPlanOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    price_monthly: Decimal
    currency: str
    features: str | None
    is_active: bool


class AdminPlanCreate(BaseModel):
    name: str
    price_monthly: Decimal
    currency: str = "VND"
    features: str | None = None
    is_active: bool = True


class AdminPlanUpdate(BaseModel):
    name: str | None = None
    price_monthly: Decimal | None = None
    currency: str | None = None
    features: str | None = None
    is_active: bool | None = None


# ─────────────────────────────────────────────
# Doanh thu (Payments) — admin
# ─────────────────────────────────────────────

class RevenueByPlan(BaseModel):
    plan_id: int
    plan_name: str
    revenue: Decimal
    payment_count: int


class AdminPaymentOut(BaseModel):
    id: int
    user_id: int
    user_email: str
    plan_name: str
    amount: Decimal
    currency: str
    status: str
    paid_at: datetime | None
    created_at: datetime


class RevenueStats(BaseModel):
    total_revenue: Decimal
    total_paid_payments: int
    by_plan: list[RevenueByPlan]
    recent_payments: list[AdminPaymentOut]


# ─────────────────────────────────────────────
# Thông báo broadcast — admin
# ─────────────────────────────────────────────

class BroadcastIn(BaseModel):
    title: str
    body: str | None = None


class BroadcastOut(BaseModel):
    recipients: int


class BroadcastHistoryItem(BaseModel):
    title: str
    body: str | None
    created_at: datetime
    recipients: int
