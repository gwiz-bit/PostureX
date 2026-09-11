"""CRUD cho bảng coach_messages — lịch sử hội thoại AI Coach."""

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.coach_message import CoachMessage

# Số tin nhắn gần nhất đưa vào ngữ cảnh khi gọi Gemini — cùng giới hạn 20 lượt
# mà `CoachChatRequest.history` từng áp trước khi có bảng này (xem
# schemas/coach.py cũ), giữ nguyên để prompt không phình to vô hạn theo thời
# gian dùng app.
DEFAULT_CONTEXT_LIMIT = 20


async def add_message(db: AsyncSession, user_id: int, role: str, content: str) -> CoachMessage:
    message = CoachMessage(user_id=user_id, role=role, content=content)
    db.add(message)
    await db.flush()
    return message


async def get_recent_messages(
    db: AsyncSession, user_id: int, limit: int = DEFAULT_CONTEXT_LIMIT
) -> list[CoachMessage]:
    """`limit` tin nhắn gần nhất, trả về theo thứ tự THỜI GIAN TĂNG DẦN (cũ
    trước) — đúng thứ tự Gemini cần để hiểu mạch hội thoại. Truy vấn theo
    `created_at DESC` rồi đảo lại, vì `ORDER BY ... ASC LIMIT n` sẽ lấy nhầm
    N tin nhắn CŨ NHẤT thay vì gần nhất.

    Sắp thêm `id` làm tiêu chí phụ — phát hiện lúc chạy cả bộ test cùng lúc:
    hai `add_message()` gọi liên tiếp có thể trùng `created_at` tới độ chính
    xác micro-giây, khiến `ORDER BY created_at` một mình không ổn định (thứ
    tự trả về đổi giữa các lần chạy). `id` tự tăng nên luôn đúng thứ tự chèn
    thật, không phụ thuộc đồng hồ hệ thống."""
    rows = (
        await db.execute(
            select(CoachMessage)
            .where(CoachMessage.user_id == user_id)
            .order_by(CoachMessage.created_at.desc(), CoachMessage.id.desc())
            .limit(limit)
        )
    ).scalars().all()
    return list(reversed(rows))


async def get_all_messages(db: AsyncSession, user_id: int) -> list[CoachMessage]:
    """Toàn bộ lịch sử, cũ trước — để hiện lại nguyên vẹn màn chat lúc mở app."""
    rows = (
        await db.execute(
            select(CoachMessage)
            .where(CoachMessage.user_id == user_id)
            .order_by(CoachMessage.created_at.asc(), CoachMessage.id.asc())
        )
    ).scalars().all()
    return list(rows)


async def clear_messages(db: AsyncSession, user_id: int) -> None:
    await db.execute(delete(CoachMessage).where(CoachMessage.user_id == user_id))
