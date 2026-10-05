"""Bản đưa lên Google Play: tắt bán hàng (PAYMENTS_ENABLED=False, mặc định) và
báo cáo nội dung AI Coach (yêu cầu của chính sách AI-Generated Content)."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.coach_report import CoachReport

pytestmark = pytest.mark.asyncio

WORKOUT = {
    "exercise": "squat",
    "total_reps": 10,
    "duration_seconds": 120,
    "accuracy_score": 88,
    "started_at": "2026-07-12T10:00:00Z",
}


def test_mac_dinh_tat_thanh_toan() -> None:
    """Mặc định phải TẮT — bật nhầm khi lên Play là vi phạm chính sách Payments."""
    assert settings.PAYMENTS_ENABLED is False


async def test_khong_gioi_han_buoi_tap_khi_tat_thanh_toan(client: AsyncClient, auth: dict) -> None:
    # Gói Free từng chỉ lưu được 3 buổi/ngày; nay mọi người tập không giới hạn.
    for _ in range(6):
        resp = await client.post("/api/v1/workouts", headers=auth, json=WORKOUT)
        assert resp.status_code == 201


async def test_checkout_bi_chan_khi_tat_thanh_toan(client: AsyncClient, auth: dict, seeded: dict) -> None:
    resp = await client.post(
        "/api/v1/subscriptions/checkout", headers=auth, json={"plan_id": seeded["premium"].id}
    )
    assert resp.status_code == 403


# ── Báo cáo AI Coach ───────────────────────────────────────────────────────

async def test_bao_cao_cau_tra_loi_ai_duoc_luu(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    resp = await client.post(
        "/api/v1/coach/report",
        headers=auth,
        json={"reason": "unsafe", "message_content": "Hãy nhịn ăn 3 ngày."},
    )
    assert resp.status_code == 201
    row = (await db_session.execute(select(CoachReport))).scalar_one()
    assert (row.user_id, row.reason, row.message_content) == (
        seeded["user"].id, "unsafe", "Hãy nhịn ăn 3 ngày.",
    )


async def test_bao_cao_ly_do_la_bi_tu_choi(client: AsyncClient, auth: dict) -> None:
    resp = await client.post(
        "/api/v1/coach/report", headers=auth, json={"reason": "spam!", "message_content": "x"}
    )
    assert resp.status_code == 422


async def test_bao_cao_noi_dung_rong_bi_tu_choi(client: AsyncClient, auth: dict) -> None:
    resp = await client.post(
        "/api/v1/coach/report", headers=auth, json={"reason": "other", "message_content": ""}
    )
    assert resp.status_code == 422


async def test_bao_cao_can_dang_nhap(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/coach/report", json={"reason": "other", "message_content": "x"}
    )
    assert resp.status_code in (401, 403)


async def test_xoa_tai_khoan_xoa_ca_bao_cao_ai(
    client: AsyncClient, auth: dict, db_session: AsyncSession
) -> None:
    await client.post(
        "/api/v1/coach/report", headers=auth, json={"reason": "other", "message_content": "abc"}
    )
    assert (await client.delete("/api/v1/users/me", headers=auth)).status_code == 204
    assert (await db_session.execute(select(CoachReport))).scalars().all() == []
