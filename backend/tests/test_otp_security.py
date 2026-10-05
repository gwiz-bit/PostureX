"""Test giới hạn số lần thử OTP — khoá lại lỗ hổng chiếm tài khoản phát
hiện qua audit repo landing page (05/10/2026, xem CHANGELOG):
`EmailOtp.attempts` có sẵn trong DB nhưng trước đây chưa từng được kiểm
tra ở `crud/otp.verify_otp`, nên một mã OTP 6 chữ số (1 triệu khả năng)
dò được không giới hạn số lần cho tới khi hết hạn.

Dùng DB thật (như test_forgot_password.py) — user/OTP tạo trong test đều
dùng-1-lần, không đụng dữ liệu thật.
"""

import secrets

import pytest
from httpx import ASGITransport, AsyncClient

from app.core.database import AsyncSessionLocal
from app.core.security import hash_password
from app.crud.otp import _MAX_VERIFY_ATTEMPTS, create_otp, verify_otp
from app.crud.role import get_role_by_name
from app.main import app
from app.models import role as _role  # noqa: F401 dang ky model cho relationship
from app.models import video as _video  # noqa: F401
from app.models import workout as _workout  # noqa: F401
from app.models.email_otp import EmailOtp
from app.models.role import USER_ROLE_NAME
from app.models.user import User


async def _create_unverified_user_with_otp() -> tuple[User, EmailOtp]:
    """Tạo 1 user CHƯA xác thực + 1 mã OTP thật trong DB — không gửi email,
    chỉ để test trực tiếp logic verify."""
    email = f"otp-test-{secrets.token_hex(4)}@example.com"
    async with AsyncSessionLocal() as db:
        role = await get_role_by_name(db, USER_ROLE_NAME)
        user = User(
            email=email,
            username=email.split("@")[0] + secrets.token_hex(3),
            hashed_password=hash_password("Passw0rd!"),
            is_email_verified=False,
            role=role,
        )
        db.add(user)
        await db.flush()
        otp = await create_otp(db, user)
        await db.commit()
        await db.refresh(user)
        await db.refresh(otp)
        return user, otp


@pytest.mark.asyncio
async def test_verify_otp_locks_out_after_max_wrong_attempts() -> None:
    """Dò sai quá _MAX_VERIFY_ATTEMPTS lần thì ngay cả mã ĐÚNG sau đó cũng
    bị từ chối — đây là bài test ĐỎ trên code cũ (trước khi sửa), vì trước
    đó không có giới hạn nào cả."""
    user, otp = await _create_unverified_user_with_otp()

    async with AsyncSessionLocal() as db:
        from sqlalchemy import select

        fresh_user = (await db.execute(select(User).where(User.id == user.id))).scalar_one()

        for _ in range(_MAX_VERIFY_ATTEMPTS):
            ok = await verify_otp(db, fresh_user, "000000")
            assert ok is False
        await db.commit()

        # Het luot - du doan DUNG ma that cung phai bi tu choi.
        ok_with_real_code = await verify_otp(db, fresh_user, otp.code)
        await db.commit()
        assert ok_with_real_code is False


@pytest.mark.asyncio
async def test_verify_otp_succeeds_within_attempt_limit() -> None:
    """Hành vi hợp lệ không bị ảnh hưởng: vài lần sai trong giới hạn, rồi
    đoán đúng vẫn phải qua được — tránh sửa quá tay khoá luôn user thật."""
    user, otp = await _create_unverified_user_with_otp()

    async with AsyncSessionLocal() as db:
        from sqlalchemy import select

        fresh_user = (await db.execute(select(User).where(User.id == user.id))).scalar_one()

        assert await verify_otp(db, fresh_user, "000000") is False
        assert await verify_otp(db, fresh_user, "111111") is False
        ok = await verify_otp(db, fresh_user, otp.code)
        await db.commit()
        assert ok is True


@pytest.mark.asyncio
async def test_verify_otp_endpoint_rate_limited_after_ten_requests() -> None:
    """slowapi giới hạn 10 request/giờ theo IP cho /verify-otp — request
    thứ 11 phải bị 429, bất kể mã đúng/sai."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        statuses = []
        for _ in range(11):
            resp = await client.post(
                "/api/v1/auth/verify-otp",
                json={"email": "khong-ton-tai@example.com", "otp_code": "123456"},
            )
            statuses.append(resp.status_code)

    assert statuses[:10] == [404] * 10  # user khong ton tai, nhung van qua duoc rate limit
    assert statuses[10] == 429


@pytest.mark.asyncio
async def test_resend_otp_endpoint_rate_limited_after_five_requests() -> None:
    """slowapi giới hạn 5 request/giờ theo IP cho /resend-otp — ngăn kẻ tấn
    công liên tục xin mã mới để có thêm lượt dò."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        statuses = []
        for _ in range(6):
            resp = await client.post(
                "/api/v1/auth/resend-otp",
                json={"email": "khong-ton-tai-resend@example.com"},
            )
            statuses.append(resp.status_code)

    assert statuses[:5] == [404] * 5
    assert statuses[5] == 429
