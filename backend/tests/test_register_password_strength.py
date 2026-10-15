"""POST /auth/register phải ép độ mạnh mật khẩu giống hệt UserUpdate —
trước đây UserCreate không có validator này, cho đăng ký mật khẩu yếu tuỳ ý
("1", rỗng...). Phát hiện khi rà lại trước khi web landing page bật lại
đăng ký công khai (REGISTRATION_ENABLED=True, repo Landing_page_PostureX)."""

import pytest

pytestmark = pytest.mark.asyncio


async def test_dang_ky_mat_khau_yeu_bi_tu_choi(client, seeded) -> None:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "weakpass@example.com", "password": "1234567", "full_name": "Weak"},
    )
    assert resp.status_code == 422


async def test_dang_ky_mat_khau_du_manh_duoc_chap_nhan(client, seeded) -> None:
    resp = await client.post(
        "/api/v1/auth/register",
        json={"email": "strongpass@example.com", "password": "Test1234!", "full_name": "Strong"},
    )
    assert resp.status_code == 201
