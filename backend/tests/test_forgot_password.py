"""Test chức năng quên/đặt lại mật khẩu (forgot-password / reset-password).

Không bao giờ in raw token ra log/output — chỉ assert kết quả. Test dùng
DB thật (như test_health.py) vì project chưa có hạ tầng mock DB riêng;
mọi user tạo trong test đều là tài khoản dùng-1-lần, không đụng tới dữ
liệu thật (admin@posturex.com...).
"""

import secrets
from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select, update

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password, verify_password
from app.crud.password_reset import MAX_RESET_ATTEMPTS, create_reset_token
from app.crud.role import get_role_by_name
from app.main import app
from app.models import role as _role  # noqa: F401 dang ky model cho relationship
from app.models import video as _video  # noqa: F401
from app.models import workout as _workout  # noqa: F401
from app.models.password_reset_token import PasswordResetToken
from app.models.role import USER_ROLE_NAME
from app.models.user import User


async def _create_verified_user(email: str) -> User:
    """Tạo 1 user đã xác thực dùng riêng cho test, không đi qua flow OTP."""
    async with AsyncSessionLocal() as db:
        role = await get_role_by_name(db, USER_ROLE_NAME)
        user = User(
            email=email,
            username=email.split("@")[0] + secrets.token_hex(3),
            hashed_password=hash_password("OldPassw0rd!"),
            is_email_verified=True,
            role=role,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
        return user


@pytest.mark.asyncio
async def test_forgot_password_same_message_for_existing_and_missing_email() -> None:
    """Chống user enumeration: 2 email (tồn tại / không tồn tại) phải trả
    về đúng cùng 1 message, cùng status code."""
    email = f"reset-test-{secrets.token_hex(4)}@example.com"
    user = await _create_verified_user(email)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp_existing = await client.post(
            "/api/v1/auth/forgot-password", json={"email": user.email}
        )
        resp_missing = await client.post(
            "/api/v1/auth/forgot-password", json={"email": "khong-ton-tai-xyz@example.com"}
        )

    assert resp_existing.status_code == 200
    assert resp_missing.status_code == 200
    assert resp_existing.json() == resp_missing.json()


async def _new_code(user_id: int) -> str:
    """Sinh mã 6 số cho user (như /forgot-password), trả về mã gốc."""
    async with AsyncSessionLocal() as db:
        # Nạp lại user trong session mới để tránh detached-instance khi
        # dùng chung object giữa 2 async session.
        fresh_user = (await db.execute(select(User).where(User.id == user_id))).scalar_one()
        code = await create_reset_token(db, fresh_user)
        await db.commit()
        return code


def _wrong_code(code: str) -> str:
    return f"{(int(code) + 1) % 1_000_000:06d}"


async def _reset(client: AsyncClient, email: str, code: str, password: str = "BrandNewPassw0rd!"):
    return await client.post(
        "/api/v1/auth/reset-password",
        json={"email": email, "code": code, "new_password": password, "confirm_password": password},
    )


async def _password_of(user_id: int) -> str:
    async with AsyncSessionLocal() as db:
        return (await db.execute(select(User).where(User.id == user_id))).scalar_one().hashed_password


@pytest.mark.asyncio
async def test_reset_code_is_six_digits_and_expires_in_five_minutes() -> None:
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)
    assert len(code) == 6 and code.isdigit()

    async with AsyncSessionLocal() as db:
        row = (
            await db.execute(
                select(PasswordResetToken).where(
                    PasswordResetToken.user_id == user.id, PasswordResetToken.used == False  # noqa: E712
                )
            )
        ).scalar_one()
        lifetime = row.expires_at - row.created_at
        # Không lưu mã gốc trong DB.
        assert code not in row.code_hash
    assert timedelta(minutes=4, seconds=50) <= lifetime <= timedelta(minutes=5, seconds=10)


@pytest.mark.asyncio
async def test_reset_password_rejects_unknown_email_and_wrong_code_with_same_message() -> None:
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        wrong = await _reset(client, user.email, _wrong_code(code))
        unknown = await _reset(client, "khong-ton-tai-xyz@example.com", code)
    assert wrong.status_code == unknown.status_code == 400
    assert wrong.json() == unknown.json()


@pytest.mark.asyncio
async def test_reset_password_old_app_sending_only_token_gets_update_message() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": secrets.token_urlsafe(16),
                "new_password": "NewPassw0rd!",
                "confirm_password": "NewPassw0rd!",
            },
        )
    assert resp.status_code == 400
    assert "cập nhật" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_reset_password_rejects_weak_password() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await _reset(client, "a@example.com", "123456", password="weak")
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_reset_password_rejects_mismatched_confirm() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "email": "a@example.com",
                "code": "123456",
                "new_password": "StrongPassw0rd!",
                "confirm_password": "DifferentPassw0rd!",
            },
        )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_reset_password_full_flow_and_code_is_single_use() -> None:
    """Mã đúng đổi được mật khẩu đúng 1 lần — dùng lại mã đó phải bị từ chối."""
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp1 = await _reset(client, user.email, f" {code} ")  # khoảng trắng thừa khi dán vẫn nhận
        assert resp1.status_code == 200
        resp2 = await _reset(client, user.email, code, password="AnotherPassw0rd!")
        assert resp2.status_code == 400

    assert verify_password("BrandNewPassw0rd!", await _password_of(user.id))


@pytest.mark.asyncio
async def test_nine_wrong_attempts_then_correct_code_still_works() -> None:
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for _ in range(MAX_RESET_ATTEMPTS - 1):
            assert (await _reset(client, user.email, _wrong_code(code))).status_code == 400
        assert (await _reset(client, user.email, code)).status_code == 200


@pytest.mark.asyncio
async def test_code_is_burned_after_ten_wrong_attempts() -> None:
    """Sai đủ 10 lần (số lần sai phải được LƯU dù route trả 400) → mã bị huỷ,
    nhập đúng sau đó cũng không đổi được mật khẩu."""
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)
    old_hash = await _password_of(user.id)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for _ in range(MAX_RESET_ATTEMPTS):
            assert (await _reset(client, user.email, _wrong_code(code))).status_code == 400
        assert (await _reset(client, user.email, code)).status_code == 400
    assert await _password_of(user.id) == old_hash


@pytest.mark.asyncio
async def test_expired_code_is_rejected() -> None:
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    code = await _new_code(user.id)
    async with AsyncSessionLocal() as db:
        await db.execute(
            update(PasswordResetToken)
            .where(PasswordResetToken.user_id == user.id)
            .values(expires_at=datetime.now(timezone.utc) - timedelta(seconds=1))
        )
        await db.commit()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        assert (await _reset(client, user.email, code)).status_code == 400


@pytest.mark.asyncio
async def test_new_code_invalidates_previous_code() -> None:
    user = await _create_verified_user(f"reset-test-{secrets.token_hex(4)}@example.com")
    first = await _new_code(user.id)
    second = await _new_code(user.id)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        if first != second:  # 1/1.000.000 khả năng trùng — khi đó không kiểm được ý này
            assert (await _reset(client, user.email, first)).status_code == 400
        assert (await _reset(client, user.email, second)).status_code == 200


@pytest.mark.asyncio
async def test_forgot_password_rate_limited_after_five_requests() -> None:
    """slowapi giới hạn 5 request/giờ theo IP — request thứ 6 phải bị 429."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        statuses = []
        for _ in range(6):
            resp = await client.post(
                "/api/v1/auth/forgot-password",
                json={"email": "rate-limit-test@example.com"},
            )
            statuses.append(resp.status_code)

    assert statuses[:5] == [200] * 5
    assert statuses[5] == 429


@pytest.mark.asyncio
async def test_rate_limit_response_uses_detail_key_in_vietnamese() -> None:
    """Thân response 429 phải có khoá `detail`, không phải `error`.

    Đây không phải chuyện thẩm mỹ: `_decode` trong lib/services/api_client.dart
    chỉ đọc khoá `detail`. Handler mặc định của slowapi trả `{"error": ...}` nên
    app Flutter rơi vào câu mặc định "Something went wrong. Please try again."
    và người dùng không biết mình bị chặn vì thao tác quá nhiều. Test này khoá
    hình dạng đó lại — xem `rate_limit_handler` trong app/core/rate_limit.py.
    """
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for _ in range(6):
            resp = await client.post(
                "/api/v1/auth/forgot-password",
                json={"email": "rate-limit-shape-test@example.com"},
            )

    assert resp.status_code == 429
    body = resp.json()
    assert "error" not in body, "handler mặc định của slowapi đã quay lại"
    assert isinstance(body.get("detail"), str)
    assert "quá nhiều lần" in body["detail"]
    # headers_enabled=True nên client biết được phải chờ bao lâu.
    assert "retry-after" in {k.lower() for k in resp.headers}
