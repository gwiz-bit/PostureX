"""Goi Pro mua tren web: endpoint kich hoat server-to-server + khoa real-time theo goi."""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes import realtime
from app.core.config import settings
from app.core.security import create_access_token
from app.crud.subscription import is_premium
from app.main import app
from app.models.subscription import Payment, SubscriptionPlan, UserSubscription

KEY = "test-web-key"
URL = "/api/v1/internal/web-subscription"


@pytest.fixture
def web_key(monkeypatch) -> dict[str, str]:
    monkeypatch.setattr(settings, "WEB_ACTIVATION_KEY", KEY)
    return {"X-Web-Key": KEY}


async def _add_pro(db: AsyncSession) -> SubscriptionPlan:
    plan = SubscriptionPlan(
        name="Pro", price_monthly=Decimal("59000.00"), currency="VND",
        features="Real-time", is_active=True,
    )
    db.add(plan)
    await db.commit()
    return plan


def _body(user_id: int, invoice: str = "PX9-AAAAAA", days: int = 30) -> dict:
    return {
        "user_id": user_id,
        "invoice": invoice,
        "amount": 59000,
        "end_date": (date.today() + timedelta(days=days)).isoformat(),
    }


@pytest.mark.asyncio
async def test_endpoint_tat_khi_chua_cau_hinh_khoa(
    client: AsyncClient, seeded: dict, monkeypatch
) -> None:
    monkeypatch.setattr(settings, "WEB_ACTIVATION_KEY", "")
    resp = await client.post(URL, headers={"X-Web-Key": "x"}, json=_body(seeded["user"].id))
    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_sai_hoac_thieu_khoa_bi_tu_choi(
    client: AsyncClient, seeded: dict, web_key: dict
) -> None:
    body = _body(seeded["user"].id)
    assert (await client.post(URL, json=body)).status_code == 401
    assert (await client.post(URL, headers={"X-Web-Key": "sai"}, json=body)).status_code == 401


@pytest.mark.asyncio
async def test_user_khong_ton_tai_la_404(
    client: AsyncClient, db_session: AsyncSession, seeded: dict, web_key: dict
) -> None:
    await _add_pro(db_session)
    resp = await client.post(URL, headers=web_key, json=_body(9999))
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_thieu_goi_pro_trong_db_la_503(
    client: AsyncClient, seeded: dict, web_key: dict
) -> None:
    resp = await client.post(URL, headers=web_key, json=_body(seeded["user"].id))
    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_kich_hoat_thanh_cong_va_user_la_premium(
    client: AsyncClient, db_session: AsyncSession, seeded: dict, auth: dict, web_key: dict
) -> None:
    await _add_pro(db_session)
    user_id = seeded["user"].id
    assert not await is_premium(db_session, user_id)

    resp = await client.post(URL, headers=web_key, json=_body(user_id))

    assert resp.status_code == 200
    assert resp.json()["created"] is True
    assert await is_premium(db_session, user_id)

    me = await client.get("/api/v1/subscriptions/me", headers=auth)
    assert me.json()["plan_name"] == "Pro"
    assert me.json()["status"] == "Active"

    payment = (await db_session.execute(select(Payment))).scalars().one()
    assert payment.transaction_no == "PX9-AAAAAA"
    assert payment.status == "Completed"
    assert payment.payment_method == "WEB_SEPAY"


@pytest.mark.asyncio
async def test_goi_lai_cung_hoa_don_khong_tao_them(
    client: AsyncClient, db_session: AsyncSession, seeded: dict, web_key: dict
) -> None:
    await _add_pro(db_session)
    body = _body(seeded["user"].id)

    first = await client.post(URL, headers=web_key, json=body)
    second = await client.post(URL, headers=web_key, json=body)

    assert first.json()["created"] is True
    assert second.status_code == 200 and second.json()["created"] is False
    subs = (await db_session.execute(select(UserSubscription))).scalars().all()
    assert len(subs) == 1


@pytest.mark.asyncio
async def test_gia_han_thi_chi_con_mot_goi_active(
    client: AsyncClient, db_session: AsyncSession, seeded: dict, web_key: dict
) -> None:
    await _add_pro(db_session)
    user_id = seeded["user"].id
    await client.post(URL, headers=web_key, json=_body(user_id, "PX1-AAAAAA", 30))
    await client.post(URL, headers=web_key, json=_body(user_id, "PX2-BBBBBB", 60))

    subs = (await db_session.execute(select(UserSubscription))).scalars().all()
    active = [s for s in subs if s.status == "Active"]
    assert len(active) == 1
    assert active[0].end_date == date.today() + timedelta(days=60)


@pytest.mark.asyncio
async def test_han_da_qua_thi_khong_con_premium(
    client: AsyncClient, db_session: AsyncSession, seeded: dict, web_key: dict
) -> None:
    await _add_pro(db_session)
    user_id = seeded["user"].id
    await client.post(URL, headers=web_key, json=_body(user_id, days=-1))
    assert not await is_premium(db_session, user_id)


# ── Khoa real-time theo goi ──────────────────────────────────────────────────


@pytest.fixture
def ws_client(monkeypatch) -> TestClient:
    monkeypatch.setattr("app.main.start_scheduler", lambda: None)
    monkeypatch.setattr("app.main.shutdown_scheduler", lambda: None)
    return TestClient(app)


def _ws_url() -> str:
    return f"/api/v1/ws/analyze?token={create_access_token('1')}"


def test_free_bi_chan_real_time_khi_bat_co(ws_client: TestClient, monkeypatch) -> None:
    monkeypatch.setattr(settings, "REALTIME_PRO_ONLY", True)

    async def not_allowed(_user_id: int) -> bool:
        return False

    monkeypatch.setattr(realtime, "_can_use_realtime", not_allowed)

    with ws_client.websocket_connect(_ws_url()) as ws:
        msg = ws.receive_json()
    assert msg["code"] == "pro_required"
    assert "Pro" in msg["error"]


def test_pro_duoc_vao_real_time_khi_bat_co(ws_client: TestClient, monkeypatch) -> None:
    monkeypatch.setattr(settings, "REALTIME_PRO_ONLY", True)

    async def allowed(_user_id: int) -> bool:
        return True

    monkeypatch.setattr(realtime, "_can_use_realtime", allowed)

    def no_db():
        raise RuntimeError("test khong duoc cham MySQL that")

    monkeypatch.setattr(realtime, "AsyncSessionLocal", no_db)

    with ws_client.websocket_connect(_ws_url()) as ws:
        ws.send_text('{"exercise": "squat"}')
        assert ws.receive_json()["status"] == "ready"


def test_tat_co_thi_free_van_dung_real_time(ws_client: TestClient, monkeypatch) -> None:
    monkeypatch.setattr(settings, "REALTIME_PRO_ONLY", False)

    async def boom(_user_id: int) -> bool:  # khong duoc goi khi co tat
        raise AssertionError("khong duoc kiem tra goi khi co tat")

    monkeypatch.setattr(realtime, "_can_use_realtime", boom)

    def no_db():
        raise RuntimeError("test khong duoc cham MySQL that")

    monkeypatch.setattr(realtime, "AsyncSessionLocal", no_db)

    with ws_client.websocket_connect(_ws_url()) as ws:
        ws.send_text('{"exercise": "squat"}')
        assert ws.receive_json()["status"] == "ready"
