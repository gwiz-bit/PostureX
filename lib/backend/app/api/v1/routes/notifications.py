"""Endpoints thông báo trong app."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud.notification import (
    count_unread,
    get_notification_by_id,
    get_notifications_by_user,
    mark_all_read,
)
from app.models.user import User
from app.schemas.notification import NotificationOut, UnreadCountOut
from app.utils.deps import get_current_user

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationOut])
async def list_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[NotificationOut]:
    """Danh sách thông báo của user hiện tại, mới nhất trước."""
    notifications = await get_notifications_by_user(db, current_user.id)
    return [NotificationOut.model_validate(n) for n in notifications]


@router.get("/unread-count", response_model=UnreadCountOut)
async def unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UnreadCountOut:
    """Số thông báo chưa đọc — cho badge trên icon chuông."""
    return UnreadCountOut(unread=await count_unread(db, current_user.id))


@router.patch("/read-all", response_model=UnreadCountOut)
async def read_all(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UnreadCountOut:
    """Đánh dấu đã đọc toàn bộ. Trả về số chưa đọc còn lại (luôn là 0)."""
    await mark_all_read(db, current_user.id)
    return UnreadCountOut(unread=0)


@router.patch("/{notification_id}/read", response_model=NotificationOut)
async def mark_read(
    notification_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> NotificationOut:
    """Đánh dấu một thông báo là đã đọc."""
    notification = await get_notification_by_id(db, notification_id, current_user.id)
    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy thông báo."
        )
    notification.is_read = True
    await db.flush()
    return NotificationOut.model_validate(notification)
