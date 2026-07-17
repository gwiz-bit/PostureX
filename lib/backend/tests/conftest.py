"""Fixture dùng chung: DB SQLite trong bộ nhớ + client đã đăng nhập.

Test chạy trên SQLite thay vì MySQL thật để `pytest` không cần cài MySQL, không
phụ thuộc máy ai, và không làm bẩn dữ liệu của nhóm. Mỗi test có một DB trắng
tinh riêng.

**Giới hạn cần biết:** SQLite không có các CHECK constraint của schema MySQL
(`CK_UserSub_Status`...). Vì vậy test ở đây KHÔNG bắt được lỗi ghi sai giá trị
Status — phần đó vẫn phải cẩn thận bằng hằng số trong `app/models/subscription.py`.
"""

import asyncio
from collections.abc import Iterator
from decimal import Decimal

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import Base, get_db
from app.core.rate_limit import limiter
from app.core.security import create_access_token, hash_password
from app.main import app

# Import mọi model để Base.metadata biết đủ bảng trước khi create_all — thiếu một
# cái là khoá ngoại trỏ vào bảng không tồn tại và create_all nổ.
from app.models.device_token import DeviceToken  # noqa: F401
from app.models.notification import Notification  # noqa: F401
from app.models.role import USER_ROLE_NAME, Role
from app.models.subscription import Payment, SubscriptionPlan, UserSubscription  # noqa: F401
from app.models.user import User
from app.models.video import Video  # noqa: F401
from app.models.workout import Workout  # noqa: F401

TEST_PASSWORD = "Test123"


@pytest.fixture(scope="session")
def event_loop() -> Iterator[asyncio.AbstractEventLoop]:
    """Ép cả phiên test chạy trên CÙNG 1 event loop.

    `app.core.database.engine` là async engine dùng chung, tạo 1 lần lúc import;
    pool của nó giữ connection gắn với event loop. pytest-asyncio mặc định tạo
    loop mới mỗi test async → pool cố đóng connection cũ trên loop đã hủy →
    `RuntimeError: Event loop is closed`. Fixture session-scoped này tránh việc đó
    (cần cho các test chạm engine thật như test_forgot_password.py)."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(autouse=True)
def _reset_rate_limiter() -> None:
    """`limiter` là Limiter singleton dùng chung (xem app/core/rate_limit.py) —
    không reset thì quota bị 'tốn' bởi test này rò rỉ sang test sau (vd khiến
    test forgot-password nhận 429 thay vì kết quả mong đợi)."""
    limiter.reset()


@pytest_asyncio.fixture
async def db_session() -> AsyncSession:
    """DB SQLite trắng, sống trong RAM, riêng cho từng test."""
    engine = create_async_engine("sqlite+aiosqlite:///:memory:")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    async with session_factory() as session:
        yield session

    await engine.dispose()


@pytest_asyncio.fixture
async def seeded(db_session: AsyncSession) -> dict:
    """Dữ liệu nền tối thiểu: 1 role, 1 user, 3 gói cước (như trong DB thật)."""
    db_session.add(Role(id=2, name=USER_ROLE_NAME))
    await db_session.flush()

    user = User(
        role_id=2,
        username="tester",
        email="tester@posturex.com",
        hashed_password=hash_password(TEST_PASSWORD),
        full_name="Tester",
        is_email_verified=True,
        is_active=True,
    )
    db_session.add(user)

    free = SubscriptionPlan(
        name="Free", price_monthly=Decimal("0.00"), currency="VND",
        features="Giới hạn 3 bài tập/ngày", is_active=True,
    )
    premium = SubscriptionPlan(
        name="Premium", price_monthly=Decimal("99000.00"), currency="VND",
        features="Không giới hạn", is_active=True,
    )
    hidden = SubscriptionPlan(
        name="Legacy", price_monthly=Decimal("50000.00"), currency="VND",
        features=None, is_active=False,
    )
    db_session.add_all([free, premium, hidden])
    await db_session.commit()

    return {"user": user, "free": free, "premium": premium, "hidden": hidden}


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncClient:
    """HTTP client gọi thẳng vào app, dùng chung session với test.

    Ghi đè `get_db` để route đọc đúng DB SQLite của test. Cố tình KHÔNG commit
    sau mỗi request (khác `get_db` thật) — giữ nguyên một session để test đọc
    được dữ liệu route vừa ghi mà không cần refresh.
    """

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest.fixture
def auth(seeded: dict) -> dict[str, str]:
    """Header Authorization của user trong `seeded`."""
    return {"Authorization": f"Bearer {create_access_token(str(seeded['user'].id))}"}
