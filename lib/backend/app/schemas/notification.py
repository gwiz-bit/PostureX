"""Schema Pydantic cho thông báo."""

from datetime import datetime

from pydantic import BaseModel


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
