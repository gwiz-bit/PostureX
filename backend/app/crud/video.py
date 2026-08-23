"""CRUD operations cho bảng videos."""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.video import Video


async def get_videos_by_user(db: AsyncSession, user_id: int) -> list[Video]:
    """Lấy tất cả video của một user, mới nhất trước."""
    result = await db.execute(
        select(Video).where(Video.user_id == user_id).order_by(Video.created_at.desc())
    )
    return list(result.scalars().all())


async def get_video_by_id(db: AsyncSession, video_id: int, user_id: int) -> Video | None:
    """Lấy video theo ID, đảm bảo thuộc về user hiện tại."""
    result = await db.execute(
        select(Video).where(Video.id == video_id, Video.user_id == user_id)
    )
    return result.scalar_one_or_none()
