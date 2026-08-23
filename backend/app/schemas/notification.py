"""Schema Pydantic cho thông báo."""

from datetime import datetime

from pydantic import BaseModel, Field


class NotificationOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    title: str
    body: str | None
    type: str | None
    is_read: bool
    created_at: datetime


class UnreadCountOut(BaseModel):
    unread: int


class DeviceTokenIn(BaseModel):
    """Token FCM app gửi lên sau khi Firebase cấp."""

    token: str = Field(min_length=1, max_length=255)
    platform: str | None = Field(default=None, max_length=20)


class WorkoutReminderIn(BaseModel):
    """Client gửi lên khi Home phát hiện hôm nay là ngày tập theo lịch cá
    nhân hóa (`WorkoutPlan` — chỉ tồn tại ở client, backend không lưu lịch
    tập) — để backend tạo thông báo + đẩy push thay vì client tự hiển thị
    banner cục bộ, giữ nhất quán với các loại thông báo khác trong app."""

    session_name: str = Field(min_length=1, max_length=150)
    exercises: list[str] = Field(default_factory=list, max_length=20)
    nutrition_tip: str | None = Field(default=None, max_length=500)


class WorkoutReminderOut(BaseModel):
    sent: bool
