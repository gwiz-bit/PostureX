"""Test chức năng quên/đặt lại mật khẩu (forgot-password / reset-password).

Không bao giờ in raw token ra log/output — chỉ assert kết quả. Test dùng
DB thật (như test_health.py) vì project chưa có hạ tầng mock DB riêng;
mọi user tạo trong test đều là tài khoản dùng-1-lần, không đụng tới dữ
liệu thật (admin@posturex.com...).
"""

import secrets

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password, verify_password
from app.crud.password_reset import create_reset_token
from app.crud.role import get_role_by_name
from app.models import role as _role  # noqa: F401 dang ky model cho relationship
from app.models import video as _video  # noqa: F401
from app.models import workout as _workout  # noqa: F401
from app.models.role import USER_ROLE_NAME
from app.models.user import User
from app.main import app


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


@pytest.mark.asyncio
async def test_reset_password_rejects_invalid_token() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": "token-khong-ton-tai-" + secrets.token_urlsafe(16),
                "new_password": "NewPassw0rd!",
                "confirm_password": "NewPassw0rd!",
            },
        )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_reset_password_rejects_weak_password() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": secrets.token_urlsafe(16),
                "new_password": "weak",
                "confirm_password": "weak",
            },
        )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_reset_password_rejects_mismatched_confirm() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": secrets.token_urlsafe(16),
                "new_password": "StrongPassw0rd!",
                "confirm_password": "DifferentPassw0rd!",
            },
        )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_reset_password_full_flow_and_token_is_single_use() -> None:
    """Token hợp lệ đổi được mật khẩu đúng 1 lần — lần thứ 2 dùng lại
    token cũ phải bị từ chối."""
    email = f"reset-test-{secrets.token_hex(4)}@example.com"
    user = await _create_verified_user(email)

    async with AsyncSessionLocal() as db:
        # Nạp lại user trong session mới để tránh detached-instance khi
        # dùng chung object giữa 2 async session.
        from sqlalchemy import select

        result = await db.execute(select(User).where(User.id == user.id))
        fresh_user = result.scalar_one()
        raw_token = await create_reset_token(db, fresh_user)
        await db.commit()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        resp1 = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": raw_token,
                "new_password": "BrandNewPassw0rd!",
                "confirm_password": "BrandNewPassw0rd!",
            },
        )
        assert resp1.status_code == 200

        # Dùng lại đúng token đó lần 2 — phải bị từ chối (used=True).
        resp2 = await client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": raw_token,
                "new_password": "AnotherPassw0rd!",
                "confirm_password": "AnotherPassw0rd!",
            },
        )
        assert resp2.status_code == 400

    async with AsyncSessionLocal() as db:
        from sqlalchemy import select

        result = await db.execute(select(User).where(User.id == user.id))
        updated_user = result.scalar_one()
        assert verify_password("BrandNewPassw0rd!", updated_user.hashed_password)


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
