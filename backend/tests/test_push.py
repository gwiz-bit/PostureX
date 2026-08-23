"""Test đăng ký thiết bị & gửi push FCM (BE-13).

Không gọi Firebase thật: `send_push()` được test bằng cách giả lập HTTP response,
còn phần còn lại chạy trên SQLite như mọi test khác.
"""

import httpx
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.crud.device_token import get_tokens_for_user, register_token
from app.services import push
from app.services.push import DEAD_TOKEN_STATUSES, send_push

# --- Endpoint đăng ký thiết bị -----------------------------------------------


@pytest.mark.asyncio
async def test_register_device_token(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    resp = await client.post(
        "/api/v1/notifications/device-token",
        headers=auth,
        json={"token": "fcm-token-abc", "platform": "android"},
    )

    assert resp.status_code == 204
    assert await get_tokens_for_user(db_session, seeded["user"].id) == ["fcm-token-abc"]


@pytest.mark.asyncio
async def test_registering_same_token_twice_does_not_duplicate(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """FCM cấp lại token định kỳ → app gọi lại endpoint này thường xuyên."""
    body = {"token": "fcm-token-abc", "platform": "android"}
    await client.post("/api/v1/notifications/device-token", headers=auth, json=body)
    await client.post("/api/v1/notifications/device-token", headers=auth, json=body)

    assert len(await get_tokens_for_user(db_session, seeded["user"].id)) == 1


@pytest.mark.asyncio
async def test_token_moves_to_the_new_owner(
    seeded: dict, db_session: AsyncSession
) -> None:
    """Hai người đăng nhập lần lượt trên cùng một máy: token phải ĐỔI CHỦ.

    Không làm vậy thì người cũ vẫn nhận push của người mới — rò rỉ dữ liệu.
    """
    from app.core.security import hash_password
    from app.models.user import User

    other = User(
        role_id=2,
        username="other",
        email="other@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True,
        is_active=True,
    )
    db_session.add(other)
    await db_session.flush()

    await register_token(db_session, seeded["user"].id, "shared-device")
    await register_token(db_session, other.id, "shared-device")

    assert await get_tokens_for_user(db_session, seeded["user"].id) == []
    assert await get_tokens_for_user(db_session, other.id) == ["shared-device"]


@pytest.mark.asyncio
async def test_unregister_device_token(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    await register_token(db_session, seeded["user"].id, "fcm-token-abc")
    await db_session.commit()

    resp = await client.request(
        "DELETE",
        "/api/v1/notifications/device-token",
        headers=auth,
        json={"token": "fcm-token-abc"},
    )

    assert resp.status_code == 204
    assert await get_tokens_for_user(db_session, seeded["user"].id) == []


@pytest.mark.asyncio
async def test_device_token_requires_auth(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/notifications/device-token", json={"token": "x"}
    )

    assert resp.status_code == 403


# --- Gửi push -----------------------------------------------------------------


@pytest.mark.asyncio
async def test_send_push_is_skipped_when_fcm_not_configured() -> None:
    """Chưa lập project Firebase thì backend vẫn chạy — push chỉ là lớp phủ."""
    assert settings.fcm_configured is False

    assert await send_push(["any-token"], "Xin chào") == []


@pytest.mark.asyncio
async def test_send_push_returns_nothing_for_empty_token_list() -> None:
    assert await send_push([], "Xin chào") == []


@pytest.mark.asyncio
async def test_send_push_reports_dead_tokens(monkeypatch: pytest.MonkeyPatch) -> None:
    """Token chết phải được trả về để nơi gọi xoá khỏi DB."""
    monkeypatch.setattr(push, "_get_access_token", lambda: "fake-access-token")
    monkeypatch.setattr(settings, "FCM_PROJECT_ID", "demo-project")

    async def fake_post(self, url, **kwargs):  # noqa: ANN001
        token = kwargs["json"]["message"]["token"]
        if token == "dead-token":
            return httpx.Response(404, json={"error": {"status": "UNREGISTERED"}})
        return httpx.Response(200, json={})

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)

    dead = await send_push(["good-token", "dead-token"], "Xin chào")

    assert dead == ["dead-token"]


@pytest.mark.asyncio
async def test_send_push_survives_network_error(monkeypatch: pytest.MonkeyPatch) -> None:
    """Firebase sập thì thông báo trong app vẫn phải lưu bình thường."""
    monkeypatch.setattr(push, "_get_access_token", lambda: "fake-access-token")
    monkeypatch.setattr(settings, "FCM_PROJECT_ID", "demo-project")

    async def boom(self, url, **kwargs):  # noqa: ANN001
        raise httpx.ConnectError("Firebase khong phan hoi")

    monkeypatch.setattr(httpx.AsyncClient, "post", boom)

    assert await send_push(["some-token"], "Xin chào") == []  # không ném lỗi


def test_dead_token_statuses_cover_unregistered() -> None:
    assert "UNREGISTERED" in DEAD_TOKEN_STATUSES
