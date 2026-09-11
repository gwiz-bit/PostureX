"""Test lịch sử chat AI Coach (11/09/2026) và việc nối chat với sinh lịch tập.

Trước đây `POST /coach/chat` nhận `history` do client tự gửi, server không
lưu gì — rời màn AI Coach là mất sạch lịch sử. Nay server tự đọc/ghi bảng
`coach_messages` (xem `crud/coach_message.py`), và `POST /coach/plan` đọc
thêm vài lượt chat gần nhất làm ngữ cảnh.

Gemini bị giả (`monkeypatch`) trong mọi test ở đây — không có test nào gọi
API thật, cùng tinh thần `test_realtime_ws.py` giả pose estimation.
"""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes import coach as coach_routes
from app.crud import coach_message as coach_message_crud
from app.schemas.coach import AiPlanResponse, PlanDayOut


@pytest.fixture(autouse=True)
def _fake_gemini_key(monkeypatch):
    """Bật cờ 'đã cấu hình AI Coach' bất kể `.env` máy chạy test có gì —
    route chỉ kiểm truthy, không gọi Gemini thật (đã giả ở từng test)."""
    monkeypatch.setattr(coach_routes.settings, "GEMINI_API_KEY", "test-key")


# ─────────────────────────────────────────────────────────────────────
# crud/coach_message.py — thuần, không qua HTTP
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_get_recent_messages_theo_dung_thu_tu_cu_truoc(db_session: AsyncSession) -> None:
    for i in range(3):
        await coach_message_crud.add_message(db_session, 1, "user", f"câu {i}")
    await db_session.commit()

    recent = await coach_message_crud.get_recent_messages(db_session, 1, limit=2)

    assert [m.content for m in recent] == ["câu 1", "câu 2"]


@pytest.mark.asyncio
async def test_get_recent_messages_chi_lay_dung_user(db_session: AsyncSession) -> None:
    await coach_message_crud.add_message(db_session, 1, "user", "của user 1")
    await coach_message_crud.add_message(db_session, 2, "user", "của user 2")
    await db_session.commit()

    recent = await coach_message_crud.get_recent_messages(db_session, 1)

    assert [m.content for m in recent] == ["của user 1"]


@pytest.mark.asyncio
async def test_clear_messages_xoa_dung_user(db_session: AsyncSession) -> None:
    await coach_message_crud.add_message(db_session, 1, "user", "giữ lại được không")
    await coach_message_crud.add_message(db_session, 2, "user", "không được xoá")
    await db_session.commit()

    await coach_message_crud.clear_messages(db_session, 1)
    await db_session.commit()

    assert await coach_message_crud.get_all_messages(db_session, 1) == []
    assert len(await coach_message_crud.get_all_messages(db_session, 2)) == 1


def test_format_chat_context_rong_thi_tra_rong() -> None:
    assert coach_routes._format_chat_context([]) == ""


# ─────────────────────────────────────────────────────────────────────
# POST /coach/chat — lưu lại lịch sử, đọc lịch sử cũ làm ngữ cảnh
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_chat_luu_ca_cau_hoi_va_cau_tra_loi(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    async def fake_ask(*, message, history, user_context):
        return f"trả lời cho: {message}"

    monkeypatch.setattr(coach_routes.ai_coach_service, "ask", fake_ask)

    resp = await client.post(
        "/api/v1/coach/chat", json={"message": "tôi nên tập gì hôm nay"}, headers=auth
    )
    assert resp.status_code == 200
    assert resp.json()["reply"] == "trả lời cho: tôi nên tập gì hôm nay"

    history = await client.get("/api/v1/coach/history", headers=auth)
    roles_and_content = [(m["role"], m["content"]) for m in history.json()]
    assert roles_and_content == [
        ("user", "tôi nên tập gì hôm nay"),
        ("model", "trả lời cho: tôi nên tập gì hôm nay"),
    ]


@pytest.mark.asyncio
async def test_chat_doc_lich_su_cu_lam_ngu_canh(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    """Lượt hỏi THỨ HAI phải thấy được lượt hỏi-đáp thứ nhất trong `history`
    truyền vào `ai_coach_service.ask` — đây chính là cái server tự làm thay
    cho việc client từng phải tự giữ và gửi lại."""
    seen_history: list = []

    async def fake_ask(*, message, history, user_context):
        seen_history.append(list(history))
        return "ok"

    monkeypatch.setattr(coach_routes.ai_coach_service, "ask", fake_ask)

    await client.post("/api/v1/coach/chat", json={"message": "câu 1"}, headers=auth)
    await client.post("/api/v1/coach/chat", json={"message": "câu 2"}, headers=auth)

    # Lượt gọi thứ hai (index 1) phải thấy đúng 2 tin nhắn của lượt trước.
    second_call_history = seen_history[1]
    assert [m.content for m in second_call_history] == ["câu 1", "ok"]


@pytest.mark.asyncio
async def test_chat_khong_con_nhan_history_tu_client(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    """Field `history` cũ (nếu client cũ lỡ còn gửi) bị bỏ qua trong im lặng
    — Pydantic bỏ field lạ mặc định, không phải lỗi 422."""
    async def fake_ask(*, message, history, user_context):
        return "ok"

    monkeypatch.setattr(coach_routes.ai_coach_service, "ask", fake_ask)

    resp = await client.post(
        "/api/v1/coach/chat",
        json={"message": "hi", "history": [{"role": "user", "content": "cũ"}]},
        headers=auth,
    )
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_history_rong_luc_chua_chat_lan_nao(client: AsyncClient, auth: dict) -> None:
    resp = await client.get("/api/v1/coach/history", headers=auth)
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_xoa_lich_su(client: AsyncClient, auth: dict, monkeypatch) -> None:
    async def fake_ask(*, message, history, user_context):
        return "ok"

    monkeypatch.setattr(coach_routes.ai_coach_service, "ask", fake_ask)
    await client.post("/api/v1/coach/chat", json={"message": "hi"}, headers=auth)

    resp = await client.delete("/api/v1/coach/history", headers=auth)
    assert resp.status_code == 200

    history = await client.get("/api/v1/coach/history", headers=auth)
    assert history.json() == []


@pytest.mark.asyncio
async def test_chat_chua_cau_hinh_gemini_bao_503(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    monkeypatch.setattr(coach_routes.settings, "GEMINI_API_KEY", "")
    resp = await client.post("/api/v1/coach/chat", json={"message": "hi"}, headers=auth)
    assert resp.status_code == 503


# ─────────────────────────────────────────────────────────────────────
# POST /coach/plan — nối với lịch sử chat
# ─────────────────────────────────────────────────────────────────────

def _fake_plan() -> AiPlanResponse:
    return AiPlanResponse(
        days=[
            PlanDayOut(
                day_label=d, session_name="Rest", is_rest=True, exercises=[], nutrition_tip="."
            )
            for d in ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        ]
    )


@pytest.mark.asyncio
async def test_sinh_lich_gui_kem_ngu_canh_chat_gan_nhat(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    async def fake_ask(*, message, history, user_context):
        return "tôi bị đau lưng, tránh bài lưng giúp tôi"

    monkeypatch.setattr(coach_routes.ai_coach_service, "ask", fake_ask)
    await client.post(
        "/api/v1/coach/chat",
        json={"message": "tôi bị đau lưng, tránh bài lưng giúp tôi"},
        headers=auth,
    )

    captured: dict = {}

    async def fake_generate_plan(*, user_context, exercise_catalogue, chat_context=""):
        captured["chat_context"] = chat_context
        return _fake_plan()

    monkeypatch.setattr(coach_routes.ai_coach_service, "generate_plan", fake_generate_plan)

    resp = await client.post("/api/v1/coach/plan", headers=auth)
    assert resp.status_code == 200
    assert "đau lưng" in captured["chat_context"]


@pytest.mark.asyncio
async def test_sinh_lich_khong_loi_khi_chua_chat_lan_nao(
    client: AsyncClient, auth: dict, monkeypatch
) -> None:
    """Chưa từng chat thì `chat_context` rỗng — không được ném lỗi vì thiếu
    lịch sử, sinh lịch phải hoạt động độc lập y như trước khi có tính năng
    nối chat."""
    captured: dict = {}

    async def fake_generate_plan(*, user_context, exercise_catalogue, chat_context=""):
        captured["chat_context"] = chat_context
        return _fake_plan()

    monkeypatch.setattr(coach_routes.ai_coach_service, "generate_plan", fake_generate_plan)

    resp = await client.post("/api/v1/coach/plan", headers=auth)
    assert resp.status_code == 200
    assert captured["chat_context"] == ""
