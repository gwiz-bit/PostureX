"""CRUD operations cho bảng Notifications."""

from datetime import datetime, timezone

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification
from app.services.notifier import dispatch_push

# Nhãn `Type` — dùng chung giữa nơi tạo (scheduler, route) và app (chọn icon).
TYPE_WORKOUT = "workout"
TYPE_PAYMENT = "payment"
TYPE_BREAK = "break"
TYPE_DAILY_SUMMARY = "daily_summary"
# Thay đổi gói do người dùng chủ động (huỷ/bật lại gia hạn).
TYPE_SUBSCRIPTION = "subscription"
# Nhắc gia hạn do job tự bắn. PHẢI là nhãn riêng, không dùng chung với
# TYPE_SUBSCRIPTION: job chống trùng bằng cách hỏi "user này đã nhận thông báo
# loại X gần đây chưa" — dùng chung nhãn thì một thông báo "đã huỷ gia hạn" sẽ
# nuốt mất lời nhắc hết hạn của cả tuần sau đó.
TYPE_SUBSCRIPTION_EXPIRY = "subscription_expiry"
# Admin gửi thông báo hàng loạt (broadcast) từ màn quản trị.
TYPE_ADMIN_BROADCAST = "admin_broadcast"


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str | None = None,
    type_: str | None = None,
) -> Notification:
    """Tạo một thông báo cho user, đồng thời đẩy push ra thiết bị.

    Đây là điểm vào dùng chung — mọi tính năng muốn báo cho người dùng đều gọi
    hàm này (thanh toán xong, hết buổi tập, job nhắc nghỉ...). Push được cắm
    ngay tại đây, nên thêm loại thông báo mới là **tự động có push**, không phải
    sửa từng nơi gọi.

    Push chạy nền và không chặn: chưa cấu hình FCM thì bỏ qua trong im lặng, lỗi
    mạng cũng không làm hỏng việc ghi thông báo (xem `services/notifier.py`).
    """
    notification = Notification(user_id=user_id, title=title, body=body, type=type_)
    db.add(notification)
    await db.flush()

    dispatch_push(user_id, title, body, type_)
    return notification


async def users_notified_since(
    db: AsyncSession, type_: str, since: datetime
) -> set[int]:
    """Tập user đã nhận thông báo loại `type_` kể từ mốc `since`.

    **Đây là hàng rào chống trùng lặp của scheduler.** Không có nó thì mỗi lần
    uvicorn khởi động lại (rất hay xảy ra với `--reload`) job có thể chạy lại và
    bắn thông báo lần hai cho cùng một người trong cùng một ngày.

    Trả về `set` để nơi gọi lọc hàng loạt bằng một truy vấn, thay vì hỏi DB một
    lần cho mỗi user.
    """
    result = await db.execute(
        select(Notification.user_id)
        .where(Notification.type == type_, Notification.created_at >= since)
        .distinct()
    )
    return set(result.scalars().all())


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


async def broadcast_notification(
    db: AsyncSession, user_ids: list[int], title: str, body: str | None
) -> int:
    """Gửi cùng một thông báo cho nhiều user (từ màn admin).

    Dùng chung một mốc `created_at` cho cả lô — nhờ vậy lịch sử broadcast có thể
    gom nhóm lại bằng `GROUP BY (title, body, created_at)` thay vì phải thêm hẳn
    một bảng "campaign" riêng cho một tính năng phụ.
    """
    now = datetime.now(timezone.utc)
    notifications = [
        Notification(user_id=uid, title=title, body=body, type=TYPE_ADMIN_BROADCAST, created_at=now)
        for uid in user_ids
    ]
    db.add_all(notifications)
    await db.flush()

    for uid in user_ids:
        dispatch_push(uid, title, body, TYPE_ADMIN_BROADCAST)

    return len(notifications)


async def list_broadcast_history(db: AsyncSession, limit: int = 20) -> list:
    """Lịch sử các lần admin gửi thông báo hàng loạt, mới nhất trước."""
    result = await db.execute(
        select(
            Notification.title,
            Notification.body,
            Notification.created_at,
            func.count().label("recipients"),
        )
        .where(Notification.type == TYPE_ADMIN_BROADCAST)
        .group_by(Notification.title, Notification.body, Notification.created_at)
        .order_by(Notification.created_at.desc())
        .limit(limit)
    )
    return result.all()
