"""CRUD token FCM của thiết bị."""

import logging

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device_token import DeviceToken

logger = logging.getLogger(__name__)


async def register_token(
    db: AsyncSession, user_id: int, token: str, platform: str | None = None
) -> DeviceToken:
    """Đăng ký token cho user. Gọi lại nhiều lần với cùng token là an toàn.

    Nếu token đã tồn tại nhưng thuộc user khác — chuyện xảy ra thật khi hai người
    đăng nhập lần lượt trên cùng một máy — thì **chuyển chủ**, không tạo dòng mới.
    Không làm vậy thì người cũ vẫn nhận được push của người mới.
    """
    result = await db.execute(select(DeviceToken).where(DeviceToken.token == token))
    existing = result.scalar_one_or_none()

    if existing is not None:
        existing.user_id = user_id
        existing.platform = platform or existing.platform
        await db.flush()
        return existing

    device = DeviceToken(user_id=user_id, token=token, platform=platform)
    db.add(device)
    await db.flush()
    return device


async def get_tokens_for_user(db: AsyncSession, user_id: int) -> list[str]:
    result = await db.execute(
        select(DeviceToken.token).where(DeviceToken.user_id == user_id)
    )
    return list(result.scalars().all())


async def delete_token(db: AsyncSession, token: str) -> None:
    """Gỡ đăng ký — gọi khi người dùng đăng xuất."""
    await db.execute(delete(DeviceToken).where(DeviceToken.token == token))


async def delete_tokens(db: AsyncSession, tokens: list[str]) -> int:
    """Xoá các token FCM báo là đã chết (app bị gỡ, token hết hạn).

    Không dọn thì danh sách token phình mãi và mỗi lần gửi push lại tốn thêm một
    lượt gọi mạng vô ích.
    """
    if not tokens:
        return 0

    result = await db.execute(delete(DeviceToken).where(DeviceToken.token.in_(tokens)))
    count = int(result.rowcount or 0)
    if count:
        logger.info("Đã xoá %d token FCM chết", count)
    return count
