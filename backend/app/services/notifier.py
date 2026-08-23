"""Cầu nối: thông báo trong DB → push ra thiết bị.

Tách khỏi `crud/notification.py` để tầng CRUD không phải biết gì về HTTP/Firebase.

**Push là fire-and-forget.** Gọi FCM có thể mất vài trăm ms cho mỗi thiết bị —
bắt request `POST /workouts` ngồi chờ chỗ đó là làm chậm app vì một việc phụ.
Nên đẩy sang task nền, và task đó **tự mở session DB riêng** (không mượn session
của request, vì request có thể đã đóng session trước khi task chạy xong).
"""

import asyncio
import logging

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.crud.device_token import delete_tokens, get_tokens_for_user
from app.services.push import send_push

logger = logging.getLogger(__name__)

# Giữ tham chiếu mạnh tới task đang chạy. asyncio chỉ giữ tham chiếu YẾU — không
# giữ ở đây thì task có thể bị dọn rác giữa chừng và push im lặng biến mất.
_background_tasks: set[asyncio.Task] = set()


async def _push_to_user(user_id: int, title: str, body: str | None, type_: str | None) -> None:
    async with AsyncSessionLocal() as db:
        tokens = await get_tokens_for_user(db, user_id)
        if not tokens:
            return

        dead = await send_push(tokens, title, body, data={"type": type_ or ""})
        if dead:
            await delete_tokens(db, dead)
            await db.commit()


def dispatch_push(user_id: int, title: str, body: str | None, type_: str | None) -> None:
    """Đẩy thông báo ra thiết bị, không chặn nơi gọi.

    Chưa cấu hình FCM thì thoát ngay — không tạo task, không tốn gì. Nhờ vậy
    backend và test chạy bình thường trên máy chưa lập project Firebase.

    Lưu ý: hàm được gọi ngay sau khi ghi thông báo vào DB, **trước khi commit**.
    Nếu request lỗi và rollback sau đó, người dùng vẫn nhận được một push cho
    thông báo không tồn tại. Hiếm, và đổi lại là code đơn giản — nhưng phải biết.
    """
    if not settings.fcm_configured:
        return

    task = asyncio.create_task(_push_to_user(user_id, title, body, type_))
    _background_tasks.add(task)
    task.add_done_callback(_background_tasks.discard)
