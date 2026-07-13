"""Cấu hình chung cho pytest.

pytest-asyncio (mặc định) tạo 1 event loop RIÊNG cho mỗi test async,
nhưng `app.core.database.engine` là 1 SQLAlchemy async engine dùng
CHUNG, tạo 1 lần lúc import — pool của nó giữ connection gắn với event
loop của test đã chạy trước đó. Sang test kế tiếp (loop mới), pool cố
đóng connection cũ trên loop đã bị hủy → `RuntimeError: Event loop is
closed`. Đây là lần đầu project có test chạm DB thật (test_health.py
trước đó không dùng DB nên chưa lộ vấn đề này).

Fix chuẩn cho engine async dùng chung: ép toàn bộ phiên test chạy trên
CÙNG 1 event loop, để pool không bao giờ bị dùng chéo giữa các loop.
"""

import asyncio
from collections.abc import Iterator

import pytest

from app.core.rate_limit import limiter


@pytest.fixture(scope="session")
def event_loop() -> Iterator[asyncio.AbstractEventLoop]:
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
def _reset_rate_limiter() -> None:
    """`limiter` là 1 Limiter singleton dùng chung cho cả app (xem
    app/core/rate_limit.py) — nếu không reset, quota bị "tốn" bởi test
    này sẽ rò rỉ sang test khác chạy sau trong cùng phiên pytest."""
    limiter.reset()
