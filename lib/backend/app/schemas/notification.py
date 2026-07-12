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
