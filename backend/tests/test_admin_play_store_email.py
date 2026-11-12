"""Admin gửi email hàng loạt thông báo app đã có trên Google Play.

Khác broadcast in-app (chỉ ghi DB): đây là SMTP thật cho từng user active,
nên cần test riêng để khoá lại hành vi đếm sent/failed khi SMTP lỗi giữa
chừng, và việc chỉ gửi cho user active (không gửi cho tài khoản đã khoá).
"""

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.role import ADMIN_ROLE_NAME, USER_ROLE_NAME, Role
from app.models.user import User

pytestmark = pytest.mark.asyncio

URL = "/api/v1/admin/notifications/play-store-email"


@pytest_asyncio.fixture
async def admin_and_users(db_session: AsyncSession) -> dict:
    db_session.add_all([
        Role(id=1, name=ADMIN_ROLE_NAME),
        Role(id=2, name=USER_ROLE_NAME),
    ])
    await db_session.flush()

    admin = User(
        role_id=1, username="boss", email="boss@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True, is_active=True,
    )
    active1 = User(
        role_id=2, username="active1", email="active1@posturex.com", full_name="Nguyễn Văn A",
        hashed_password=hash_password("Test123"), is_email_verified=True, is_active=True,
    )
    active2 = User(
        role_id=2, username="active2", email="active2@posturex.com", full_name=None,
        hashed_password=hash_password("Test123"), is_email_verified=True, is_active=True,
    )
    locked = User(
        role_id=2, username="locked", email="locked@posturex.com",
        hashed_password=hash_password("Test123"), is_email_verified=True, is_active=False,
    )
    db_session.add_all([admin, active1, active2, locked])
    await db_session.commit()
    return {"admin": admin}


async def test_khong_dang_nhap_bi_tu_choi(client) -> None:
    resp = await client.post(URL)
    assert resp.status_code in (401, 403)


async def test_gui_cho_dung_user_active_bo_qua_tai_khoan_khoa(
    client, admin_and_users, monkeypatch
) -> None:
    sent_to: list[str] = []

    async def fake_send(to_email: str, full_name: str | None) -> None:
        sent_to.append(to_email)

    monkeypatch.setattr(
        "app.api.v1.routes.admin.send_play_store_announcement_email", fake_send
    )

    from app.core.security import create_access_token
    admin = admin_and_users["admin"]
    token = create_access_token(admin.id)

    resp = await client.post(URL, headers={"Authorization": f"Bearer {token}"})

    assert resp.status_code == 200
    data = resp.json()
    assert data == {"sent": 3, "failed": 0}  # admin + active1 + active2, KHONG tinh locked
    assert set(sent_to) == {"boss@posturex.com", "active1@posturex.com", "active2@posturex.com"}
    assert "locked@posturex.com" not in sent_to


async def test_loi_smtp_mot_nguoi_khong_chan_nguoi_con_lai(
    client, admin_and_users, monkeypatch
) -> None:
    """Một user gửi lỗi (vd email service lỗi SMTP) vẫn phải gửi tiếp cho
    những người sau — không để một lỗi làm mất cả lô."""
    async def flaky_send(to_email: str, full_name: str | None) -> None:
        if to_email == "active1@posturex.com":
            raise RuntimeError("SMTP that bai gia lap")

    monkeypatch.setattr(
        "app.api.v1.routes.admin.send_play_store_announcement_email", flaky_send
    )

    from app.core.security import create_access_token
    admin = admin_and_users["admin"]
    token = create_access_token(admin.id)

    resp = await client.post(URL, headers={"Authorization": f"Bearer {token}"})

    assert resp.status_code == 200
    assert resp.json() == {"sent": 2, "failed": 1}
