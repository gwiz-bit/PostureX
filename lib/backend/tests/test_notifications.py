"""Test các endpoint thông báo (BE-13)."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token, hash_password
from app.crud.notification import create_notification
from app.models.user import User


@pytest.mark.asyncio
async def test_list_is_empty_for_new_user(client: AsyncClient, auth: dict, seeded: dict) -> None:
    resp = await client.get("/api/v1/notifications", headers=auth)

    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_unread_count_matches_unread_notifications(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    for i in range(3):
        await create_notification(db_session, seeded["user"].id, f"Thông báo {i}", type_="system")
    await db_session.commit()

    resp = await client.get("/api/v1/notifications/unread-count", headers=auth)

    assert resp.json() == {"unread": 3}


@pytest.mark.asyncio
async def test_mark_one_read_decrements_the_count(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    notification = await create_notification(db_session, seeded["user"].id, "Xin chào")
    await db_session.commit()

    resp = await client.patch(f"/api/v1/notifications/{notification.id}/read", headers=auth)

    assert resp.status_code == 200
    assert resp.json()["is_read"] is True
    unread = await client.get("/api/v1/notifications/unread-count", headers=auth)
    assert unread.json() == {"unread": 0}


@pytest.mark.asyncio
async def test_read_all_clears_everything(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    for i in range(5):
        await create_notification(db_session, seeded["user"].id, f"Thông báo {i}")
    await db_session.commit()

    resp = await client.patch("/api/v1/notifications/read-all", headers=auth)

    assert resp.status_code == 200
    assert resp.json() == {"unread": 0}


@pytest.mark.asyncio
async def test_cannot_read_someone_elses_notification(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """Thông báo của người khác phải trả 404, không phải 200."""
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
    theirs = await create_notification(db_session, other.id, "Bí mật của người khác")
    await db_session.commit()

    resp = await client.patch(f"/api/v1/notifications/{theirs.id}/read", headers=auth)

    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_list_only_returns_own_notifications(
    client: AsyncClient, seeded: dict, db_session: AsyncSession
) -> None:
    other = User(
        role_id=2,
        username="other2",
        email="other2@posturex.com",
        hashed_password=hash_password("Test123"),
        is_email_verified=True,
        is_active=True,
    )
    db_session.add(other)
    await db_session.flush()
    await create_notification(db_session, seeded["user"].id, "Của tôi")
    await create_notification(db_session, other.id, "Của người khác")
    await db_session.commit()

    other_auth = {"Authorization": f"Bearer {create_access_token(str(other.id))}"}
    resp = await client.get("/api/v1/notifications", headers=other_auth)

    titles = [n["title"] for n in resp.json()]
    assert titles == ["Của người khác"]


@pytest.mark.asyncio
async def test_notifications_require_auth(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/notifications")

    assert resp.status_code == 403
