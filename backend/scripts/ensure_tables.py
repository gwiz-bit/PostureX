"""Tạo các bảng còn thiếu trong Base.metadata — KHÔNG đụng vào bảng đã có sẵn.

Khác với create_tables.py (script đó xoá + tạo lại "videos"/"workouts" mỗi
lần chạy, chỉ nên chạy tay khi cố ý reset), script này an toàn để chạy ở mọi
lần khởi động backend: mỗi model chỉ được tạo bảng nếu bảng đó chưa tồn tại
(checkfirst=True). Dùng cho trường hợp máy vừa pull code có model mới nhưng
database cũ chưa có bảng tương ứng.
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import Base, engine
from app.models import (  # noqa: F401 đăng ký hết model để Base.metadata đầy đủ
    device_token,
    email_otp,
    exercise,
    goal,
    muscle_group,
    notification,
    password_reset_token,
    role,
    subscription,
    user,
    user_profile,
    video,
    workout,
)


async def main() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all, checkfirst=True)
    print("Da dong bo bang con thieu (khong dong gi bang da co san).")
    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
