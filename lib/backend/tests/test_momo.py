"""Test tích hợp MoMo (BE-14).

Chữ ký được test bằng hàm thuần (không cần mạng). Luồng callback được test bằng
cách **giả lập phản hồi của MoMo** — không gọi sandbox thật, để `pytest` chạy
được cả khi không có internet.
"""

import hashlib
import hmac
from decimal import Decimal

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.crud.subscription import get_active_subscription
from app.models.subscription import (
    PAYMENT_FAILED,
    PAYMENT_PAID,
    PAYMENT_PENDING,
    Payment,
)
from app.services import momo

ORDER_INFO = "Thanh toan goi Premium"


def _sign(raw: str) -> str:
    return hmac.new(
        settings.MOMO_SECRET_KEY.encode(), raw.encode(), hashlib.sha256
    ).hexdigest()


# --- Chữ ký (hàm thuần) -------------------------------------------------------


def test_create_body_signs_fields_in_alphabetical_order() -> None:
    """Sai thứ tự một trường là MoMo trả 'Signature không hợp lệ'."""
    body = momo.build_create_body(
        amount=99000,
        order_id="PX1",
        order_info=ORDER_INFO,
        redirect_url="http://host/return",
        ipn_url="http://host/ipn",
        request_id="req-1",
    )

    expected_raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}"
        f"&amount=99000&extraData=&ipnUrl=http://host/ipn&orderId=PX1"
        f"&orderInfo={ORDER_INFO}&partnerCode={settings.MOMO_PARTNER_CODE}"
        f"&redirectUrl=http://host/return&requestId=req-1&requestType=captureWallet"
    )
    assert body["signature"] == _sign(expected_raw)


def test_create_body_sends_amount_as_string() -> None:
    """MoMo từ chối `amount` kiểu số trong JSON."""
    body = momo.build_create_body(
        amount=99000, order_id="PX1", order_info=ORDER_INFO,
        redirect_url="http://h/r", ipn_url="http://h/i",
    )

    assert body["amount"] == "99000"
    assert isinstance(body["amount"], str)


def test_query_body_uses_its_own_field_order() -> None:
    """Chữ ký /query chỉ gồm 4 trường — khác hẳn lúc tạo đơn."""
    body = momo.build_query_body("PX1", request_id="req-1")

    expected_raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}&orderId=PX1"
        f"&partnerCode={settings.MOMO_PARTNER_CODE}&requestId=req-1"
    )
    assert body["signature"] == _sign(expected_raw)


def test_valid_ipn_signature_is_accepted() -> None:
    payload = {
        "partnerCode": settings.MOMO_PARTNER_CODE, "orderId": "PX1", "requestId": "r1",
        "amount": "99000", "orderInfo": ORDER_INFO, "orderType": "momo_wallet",
        "transId": "123", "resultCode": "0", "message": "Thanh cong",
        "payType": "qr", "responseTime": "1", "extraData": "",
    }
    raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}&amount=99000&extraData="
        f"&message=Thanh cong&orderId=PX1&orderInfo={ORDER_INFO}"
        f"&orderType=momo_wallet&partnerCode={settings.MOMO_PARTNER_CODE}"
        f"&payType=qr&requestId=r1&responseTime=1&resultCode=0&transId=123"
    )
    payload["signature"] = _sign(raw)

    assert momo.verify_ipn_signature(payload) is True


def test_tampered_ipn_is_rejected() -> None:
    """Kẻ tấn công sửa số tiền → chữ ký không còn khớp."""
    payload = {
        "partnerCode": settings.MOMO_PARTNER_CODE, "orderId": "PX1", "requestId": "r1",
        "amount": "99000", "orderInfo": ORDER_INFO, "orderType": "momo_wallet",
        "transId": "123", "resultCode": "0", "message": "Thanh cong",
        "payType": "qr", "responseTime": "1", "extraData": "",
    }
    raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}&amount=99000&extraData="
        f"&message=Thanh cong&orderId=PX1&orderInfo={ORDER_INFO}"
        f"&orderType=momo_wallet&partnerCode={settings.MOMO_PARTNER_CODE}"
        f"&payType=qr&requestId=r1&responseTime=1&resultCode=0&transId=123"
    )
    payload["signature"] = _sign(raw)
    payload["amount"] = "1000"  # sửa sau khi ký

    assert momo.verify_ipn_signature(payload) is False


def test_ipn_without_signature_is_rejected() -> None:
    assert momo.verify_ipn_signature({"orderId": "PX1"}) is False


def test_is_successful_handles_string_and_int() -> None:
    """MoMo lúc trả số, lúc trả chuỗi — cả hai đều phải hiểu đúng."""
    assert momo.is_successful(0) is True
    assert momo.is_successful("0") is True
    assert momo.is_successful(1006) is False
    assert momo.is_successful(None) is False


# --- Luồng callback (giả lập MoMo) --------------------------------------------


@pytest_asyncio.fixture
async def pending_payment(seeded: dict, db_session: AsyncSession) -> Payment:
    """Một đơn Pending 99.000đ, sẵn sàng để chốt."""
    from app.crud.subscription import create_pending_order

    _, payment = await create_pending_order(db_session, seeded["user"].id, seeded["premium"])
    await db_session.commit()
    return payment


def _fake_query(result: dict):
    async def _query(order_id: str) -> dict:
        return result
    return _query


@pytest.mark.asyncio
async def test_return_activates_plan_when_momo_confirms_payment(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 0, "amount": 99000, "transId": 999, "message": "ok"}),
    )

    resp = await client.get(f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}")

    assert resp.status_code == 200
    assert pending_payment.status == PAYMENT_PAID
    assert await get_active_subscription(db_session, seeded["user"].id) is not None


@pytest.mark.asyncio
async def test_return_does_not_trust_the_url_only_momo(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Người dùng tự sửa URL thành resultCode=0, nhưng MoMo nói CHƯA trả tiền.

    Đây là lý do backend hỏi thẳng MoMo thay vì đọc tham số trên URL.
    """
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 1006, "message": "Nguoi dung tu choi"}),
    )

    resp = await client.get(
        f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}&resultCode=0"
    )

    assert resp.status_code == 200
    assert pending_payment.status == PAYMENT_FAILED
    assert await get_active_subscription(db_session, seeded["user"].id) is None


@pytest.mark.asyncio
async def test_pending_payment_is_not_killed(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Bug thật, chỉ lộ ra khi chạy với MoMo sandbox: resultCode=1000 nghĩa là
    "chờ người dùng xác nhận", KHÔNG phải thất bại.

    Người dùng đang dở tay quét QR mà lỡ quay về app → đơn bị đánh Failed oan.
    Họ trả tiền xong, IPN về, nhưng đơn đã mang trạng thái hỏng.
    """
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({
            "resultCode": 1000,
            "message": "Giao dich da duoc khoi tao, cho nguoi dung xac nhan",
        }),
    )

    await client.get(f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}")

    assert pending_payment.status == PAYMENT_PENDING  # KHÔNG phải Failed
    assert await get_active_subscription(db_session, seeded["user"].id) is None


@pytest.mark.asyncio
async def test_pending_order_can_still_be_settled_later(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """...và vì không bị giết oan, đơn đó vẫn chốt được khi người dùng trả xong."""
    url = f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}"

    monkeypatch.setattr(momo, "query_payment", _fake_query({"resultCode": 1000}))
    await client.get(url)

    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 0, "amount": 99000, "transId": 7, "message": "ok"}),
    )
    await client.get(url)

    assert pending_payment.status == PAYMENT_PAID
    assert await get_active_subscription(db_session, seeded["user"].id) is not None


@pytest.mark.asyncio
async def test_amount_mismatch_is_rejected(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Trả 1.000đ cho gói 99.000đ → không được kích hoạt."""
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 0, "amount": 1000, "transId": 1, "message": "ok"}),
    )

    await client.get(f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}")

    assert pending_payment.status == PAYMENT_FAILED
    assert await get_active_subscription(db_session, seeded["user"].id) is None


@pytest.mark.asyncio
async def test_return_is_idempotent(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Bấm F5 trên trang kết quả → không được cộng thêm 30 ngày lần nữa."""
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 0, "amount": 99000, "transId": 1, "message": "ok"}),
    )
    url = f"/api/v1/payments/momo/return?orderId=PX{pending_payment.id}"

    await client.get(url)
    first_end = (await get_active_subscription(db_session, seeded["user"].id)).end_date
    await client.get(url)
    second_end = (await get_active_subscription(db_session, seeded["user"].id)).end_date

    assert first_end == second_end


@pytest.mark.asyncio
async def test_unknown_order_id_is_handled(client: AsyncClient, seeded: dict) -> None:
    resp = await client.get("/api/v1/payments/momo/return?orderId=RAC")

    assert resp.status_code == 200  # trang lỗi, không phải 500
    assert "không hợp lệ" in resp.text.lower()


@pytest.mark.asyncio
async def test_ipn_with_bad_signature_does_not_activate(
    client: AsyncClient, db_session: AsyncSession, seeded: dict,
    pending_payment: Payment, monkeypatch: pytest.MonkeyPatch,
) -> None:
    """IPN giả mạo (không có secretKey) không được kích hoạt gói."""
    monkeypatch.setattr(
        momo, "query_payment",
        _fake_query({"resultCode": 0, "amount": 99000, "transId": 1, "message": "ok"}),
    )

    resp = await client.post(
        "/api/v1/payments/momo/ipn",
        json={"orderId": f"PX{pending_payment.id}", "resultCode": "0", "signature": "gia-mao"},
    )

    assert resp.status_code == 204
    assert pending_payment.status != PAYMENT_PAID
    assert await get_active_subscription(db_session, seeded["user"].id) is None


@pytest.mark.asyncio
async def test_checkout_rejects_amount_below_momo_minimum(
    client: AsyncClient, auth: dict, seeded: dict, db_session: AsyncSession
) -> None:
    """MoMo không nhận đơn dưới 1.000đ — chặn ở ta, đừng để MoMo báo lỗi khó hiểu."""
    seeded["hidden"].price_monthly = Decimal("500.00")
    seeded["hidden"].is_active = True
    await db_session.commit()

    resp = await client.post(
        "/api/v1/subscriptions/checkout", headers=auth, json={"plan_id": seeded["hidden"].id}
    )

    assert resp.status_code == 400
    assert "MoMo" in resp.json()["detail"]
