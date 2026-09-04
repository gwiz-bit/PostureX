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


# ─────────────────────────────────────────────
# Ngưỡng phân tích tư thế theo từng bài tập
# ─────────────────────────────────────────────
#
# Thay cho schema `AIConfig` cũ, vốn ghi cứng 7 trường cho riêng squat. Ba
# vấn đề của bản cũ: giá trị chỉ nằm trong RAM nên mất mỗi lần restart; nó sửa
# biến toàn cục của module `squat` nên áp cho cả 21 biến thể squat cùng lúc;
# và 4 trong 7 trường không có đường nào tới analyzer (xem phần đầu
# `app/ml/analyzers/tunables.py`).
#
# Bản này ghi vào `ExercisePostureRules` — đúng bảng mà analyzer đọc lúc chạy.


class TunableOut(BaseModel):
    """Một ngưỡng chỉnh được của một bài tập."""

    key: str
    label: str

    #: Giá trị analyzer dùng khi bài này chưa được ghi đè.
    default: float
    #: Giá trị đang ghi đè trong DB; `None` = đang chạy bằng `default`.
    current: float | None

    minimum: float
    maximum: float
    #: Đổi ngưỡng này là đổi cách ĐẾM rep, không chỉ cách chấm điểm.
    affects_rep_count: bool

    #: Đơn vị hiển thị — "°" cho góc, rỗng cho tỉ lệ. Giao diện không được tự
    #: gắn "°" vào mọi giá trị: `knee_overshoot` là tỉ lệ theo chiều rộng
    #: khung hình, hiện "0.05°" sẽ khiến admin hiểu sai thứ mình đang chỉnh.
    unit: str
    #: Bước nhảy của thanh trượt.
    step: float


class TunableExerciseOut(BaseModel):
    """Một bài tập trong danh sách chọn của màn admin."""

    model_config = {"from_attributes": True}

    id: int
    name: str
    #: Tên class analyzer phụ trách — hai bài cùng analyzer dùng chung bộ khoá
    #: ngưỡng, nhưng giá trị thì riêng từng bài.
    analyzer: str
    #: Số ngưỡng đang ghi đè. 0 = bài này chạy hoàn toàn bằng mặc định.
    override_count: int


class ExerciseRulesOut(BaseModel):
    """Toàn bộ ngưỡng chỉnh được của một bài, kèm giá trị hiện tại."""

    exercise_id: int
    exercise_name: str
    analyzer: str
    tunables: list[TunableOut]


class ExerciseRulesUpdate(BaseModel):
    """Đặt lại ngưỡng ghi đè của một bài.

    `values` là trạng thái ĐẦY ĐỦ mong muốn: khoá nào không có trong đây sẽ bị
    xoá khỏi DB và bài quay về mặc định của analyzer. Gửi `{}` là bỏ hết ghi
    đè.
    """

    values: dict[str, float]


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
