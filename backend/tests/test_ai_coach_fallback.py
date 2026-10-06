"""Test logic retry/fallback model của AI Coach khi Gemini báo lỗi — khoá
lại lỗi phát hiện qua audit log production thật (05/10/2026, xem
CHANGELOG): trước đây lỗi 503 (quá tải) chỉ retry cùng model, KHÔNG bao
giờ chuyển sang model dự phòng dù danh sách đó đã có sẵn và đang dùng đúng
cho lỗi 400/404/429 — khiến user vẫn nhận lỗi nếu model chính quá tải kéo
dài hơn khung thời gian retry ngắn.

Mock trực tiếp `_client()` (không gọi Gemini thật) — tương tự cách
test_coach.py mock Gemini, nhưng ở tầng sâu hơn để kiểm đúng logic retry/
fallback bên trong `_generate_with_retry`, không chỉ hành vi route.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from google.genai import errors as genai_errors

from app.services import ai_coach_service


def _api_error(code: int) -> genai_errors.APIError:
    return genai_errors.APIError(code=code, response_json={})


def _fake_client(side_effects_by_model: dict[str, list]):
    """Dựng 1 fake Gemini client: mỗi model trong `side_effects_by_model`
    có 1 danh sách kết quả lần lượt trả về (exception để raise, hoặc giá
    trị để return) mỗi lần bị gọi."""
    call_state: dict[str, int] = {}

    async def fake_generate_content(*, model: str, **kwargs):
        idx = call_state.get(model, 0)
        call_state[model] = idx + 1
        effects = side_effects_by_model.get(model, [])
        if idx >= len(effects):
            raise AssertionError(f"Model {model} bị gọi quá số lần dự kiến ({idx + 1})")
        effect = effects[idx]
        if isinstance(effect, Exception):
            raise effect
        return effect

    client = MagicMock()
    client.aio.models.generate_content = AsyncMock(side_effect=fake_generate_content)
    return client


@pytest.mark.asyncio
async def test_503_lap_lai_het_luot_thi_chuyen_model_du_phong(monkeypatch) -> None:
    """ĐỎ trên code cũ: model chính 503 đủ 3 lần, model dự phòng đầu tiên
    trả về thành công — phải nhận kết quả từ model dự phòng thay vì raise."""
    fake_response = object()
    client = _fake_client({
        "gemini-3.8-flash": [_api_error(503), _api_error(503), _api_error(503)],
        "gemini-2.0-flash": [fake_response],
    })
    monkeypatch.setattr(ai_coach_service, "_client", lambda: client)
    monkeypatch.setattr(ai_coach_service.settings, "GEMINI_MODEL", "gemini-3.8-flash")
    monkeypatch.setattr(ai_coach_service, "_RETRY_DELAYS_SECONDS", (0, 0))

    result = await ai_coach_service._generate_with_retry(
        model="gemini-3.8-flash", contents=[]
    )

    assert result is fake_response


@pytest.mark.asyncio
async def test_429_van_chuyen_model_ngay_khong_can_retry(monkeypatch) -> None:
    """Hồi quy: lỗi 429 (hết quota) ở model chính vẫn phải chuyển NGAY sang
    model dự phòng (không retry 3 lần như 503) — hành vi cũ không bị phá."""
    fake_response = object()
    client = _fake_client({
        "gemini-3.8-flash": [_api_error(429)],
        "gemini-2.0-flash": [fake_response],
    })
    monkeypatch.setattr(ai_coach_service, "_client", lambda: client)
    monkeypatch.setattr(ai_coach_service.settings, "GEMINI_MODEL", "gemini-3.8-flash")
    monkeypatch.setattr(ai_coach_service, "_RETRY_DELAYS_SECONDS", (0, 0))

    result = await ai_coach_service._generate_with_retry(
        model="gemini-3.8-flash", contents=[]
    )

    assert result is fake_response


@pytest.mark.asyncio
async def test_loi_mang_chuyen_model_du_phong(monkeypatch) -> None:
    """Network error (timeout, SSL...) cũng phải thử model dự phòng thay vì
    raise ngay — không chỉ APIError mới được hưởng fallback."""
    fake_response = object()
    client = _fake_client({
        "gemini-3.8-flash": [ConnectionError("network unreachable")],
        "gemini-2.0-flash": [fake_response],
    })
    monkeypatch.setattr(ai_coach_service, "_client", lambda: client)
    monkeypatch.setattr(ai_coach_service.settings, "GEMINI_MODEL", "gemini-3.8-flash")
    monkeypatch.setattr(ai_coach_service, "_RETRY_DELAYS_SECONDS", (0, 0))

    result = await ai_coach_service._generate_with_retry(
        model="gemini-3.8-flash", contents=[]
    )

    assert result is fake_response


@pytest.mark.asyncio
async def test_tat_ca_model_deu_503_thi_raise_loi_cuoi(monkeypatch) -> None:
    """Không treo vô hạn, không nuốt lỗi âm thầm: nếu CẢ model chính lẫn
    toàn bộ model dự phòng đều 503 hết lượt — raise lỗi 503 cuối cùng."""
    client = _fake_client({
        "gemini-3.8-flash": [_api_error(503)] * 3,
        "gemini-2.0-flash": [_api_error(503)] * 3,
        "gemini-1.5-flash": [_api_error(503)] * 3,
    })
    monkeypatch.setattr(ai_coach_service, "_client", lambda: client)
    monkeypatch.setattr(ai_coach_service.settings, "GEMINI_MODEL", "gemini-3.8-flash")
    monkeypatch.setattr(ai_coach_service, "_RETRY_DELAYS_SECONDS", (0, 0))

    with pytest.raises(genai_errors.APIError) as exc_info:
        await ai_coach_service._generate_with_retry(model="gemini-3.8-flash", contents=[])

    assert exc_info.value.code == 503
