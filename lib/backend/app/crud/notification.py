"""CRUD operations cho bảng Notifications."""

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str | None = None,
    type_: str | None = None,
) -> Notification:
    """Tạo một thông báo cho user.

    Đây là điểm vào dùng chung — mọi tính năng muốn báo cho người dùng đều gọi
    hàm này (vd: thanh toán thành công). Khi làm FCM push sau này, chỗ đẩy
    notification ra thiết bị cũng nên cắm vào đây, để không phải sửa từng nơi gọi.
    """
    notification = Notification(user_id=user_id, title=title, body=body, type=type_)
    db.add(notification)
    await db.flush()
    return notification


async def get_notifications_by_user(db: AsyncSession, user_id: int) -> list[Notification]:
    """Lấy thông báo của một user, mới nhất trước."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc(), Notification.id.desc())
    )
    return list(result.scalars().all())


async def get_notification_by_id(
    db: AsyncSession, notification_id: int, user_id: int
) -> Notification | None:
    """Lấy một thông báo, đảm bảo thuộc về user hiện tại."""
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id, Notification.user_id == user_id
        )
    )
    return result.scalar_one_or_none()


async def count_unread(db: AsyncSession, user_id: int) -> int:
    """Đếm số thông báo chưa đọc — dùng cho badge trên icon chuông."""
    result = await db.execute(
        select(func.count())
        .select_from(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
    )
    return int(result.scalar_one())


async def mark_all_read(db: AsyncSession, user_id: int) -> int:
    """Đánh dấu đã đọc toàn bộ thông báo chưa đọc. Trả về số dòng đã cập nhật."""
    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user_id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    return int(result.rowcount or 0)
