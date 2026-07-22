"""Tích hợp cổng thanh toán MoMo (AIO v2).

Thay cho VNPay. Lý do đổi: VNPay bắt đăng ký merchant mới có mã thật, còn MoMo
**công bố công khai bộ khoá sandbox** trong repo mẫu chính thức
(github.com/momo-wallet/payment) → chạy được ngay, không phải chờ ai duyệt.

MoMo còn có một thứ VNPay không có: **API tra cứu trạng thái giao dịch**
(`/query`). Nhờ nó, ta không phải tin vào tham số MoMo gắn trên URL redirect —
sau khi người dùng quay về, backend **hỏi thẳng MoMo** "đơn này trả tiền chưa".
Đây là lý do luồng MoMo an toàn hơn hẳn VNPay trong điều kiện chạy localhost:
VNPay bắt buộc phải có IPN (cần URL công khai) mới chắc chắn được, MoMo thì không.

Quy tắc ký (sai một dấu `&` là "Signature không hợp lệ"):
  • Chuỗi ký là các trường **theo đúng thứ tự alphabet**, nối `key=value&key=value`
  • **KHÔNG url-encode** giá trị (khác VNPay!)
  • HMAC-SHA256 với secretKey, kết quả hex thường

Các hàm dựng/kiểm chữ ký ở đây là **hàm thuần** — test được mà không cần mạng.
Chỉ `create_payment()` và `query_payment()` mới gọi ra ngoài.
"""

import hashlib
import hmac
import logging
import uuid

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

# resultCode của MoMo. 0 = thành công (dùng chung cho cả /create, /query và IPN).
MOMO_SUCCESS_CODE = 0
# 1000 = đơn đã tạo, đang chờ người dùng thanh toán — chưa phải thất bại.
MOMO_PENDING_CODE = 1000

# MoMo chỉ nhận đơn trong khoảng này (VND).
MOMO_MIN_AMOUNT = 1_000
MOMO_MAX_AMOUNT = 50_000_000


def _sign(raw: str) -> str:
    return hmac.new(
        settings.MOMO_SECRET_KEY.encode("utf-8"), raw.encode("utf-8"), hashlib.sha256
    ).hexdigest()


def build_create_body(
    *,
    amount: int,
    order_id: str,
    order_info: str,
    redirect_url: str,
    ipn_url: str,
    request_id: str | None = None,
    extra_data: str = "",
) -> dict:
    """Dựng body (kèm chữ ký) cho `POST /v2/gateway/api/create`.

    `order_id` phải **duy nhất** với mỗi partner — dùng PaymentId của ta.
    """
    request_id = request_id or str(uuid.uuid4())
    request_type = "captureWallet"

    raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}"
        f"&amount={amount}"
        f"&extraData={extra_data}"
        f"&ipnUrl={ipn_url}"
        f"&orderId={order_id}"
        f"&orderInfo={order_info}"
        f"&partnerCode={settings.MOMO_PARTNER_CODE}"
        f"&redirectUrl={redirect_url}"
        f"&requestId={request_id}"
        f"&requestType={request_type}"
    )

    return {
        "partnerCode": settings.MOMO_PARTNER_CODE,
        "accessKey": settings.MOMO_ACCESS_KEY,
        "requestId": request_id,
        "amount": str(amount),
        "orderId": order_id,
        "orderInfo": order_info,
        "redirectUrl": redirect_url,
        "ipnUrl": ipn_url,
        "extraData": extra_data,
        "requestType": request_type,
        "lang": "vi",
        "signature": _sign(raw),
    }


def build_query_body(order_id: str, request_id: str | None = None) -> dict:
    """Dựng body cho `POST /v2/gateway/api/query` — hỏi MoMo trạng thái một đơn."""
    request_id = request_id or str(uuid.uuid4())
    raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}"
        f"&orderId={order_id}"
        f"&partnerCode={settings.MOMO_PARTNER_CODE}"
        f"&requestId={request_id}"
    )
    return {
        "partnerCode": settings.MOMO_PARTNER_CODE,
        "accessKey": settings.MOMO_ACCESS_KEY,
        "requestId": request_id,
        "orderId": order_id,
        "lang": "vi",
        "signature": _sign(raw),
    }


def verify_ipn_signature(payload: dict) -> bool:
    """Xác minh chữ ký MoMo gửi kèm IPN.

    Thứ tự trường **khác** lúc tạo đơn — đây là chỗ rất dễ sai. Không có
    secretKey thì không giả mạo được callback này.
    """
    received = payload.get("signature", "")
    if not received:
        return False

    raw = (
        f"accessKey={settings.MOMO_ACCESS_KEY}"
        f"&amount={payload.get('amount', '')}"
        f"&extraData={payload.get('extraData', '')}"
        f"&message={payload.get('message', '')}"
        f"&orderId={payload.get('orderId', '')}"
        f"&orderInfo={payload.get('orderInfo', '')}"
        f"&orderType={payload.get('orderType', '')}"
        f"&partnerCode={payload.get('partnerCode', '')}"
        f"&payType={payload.get('payType', '')}"
        f"&requestId={payload.get('requestId', '')}"
        f"&responseTime={payload.get('responseTime', '')}"
        f"&resultCode={payload.get('resultCode', '')}"
        f"&transId={payload.get('transId', '')}"
    )
    # compare_digest: so sánh hằng thời gian, tránh rò rỉ qua thời gian phản hồi.
    return hmac.compare_digest(_sign(raw), received)


def is_successful(result_code: object) -> bool:
    """MoMo trả resultCode có lúc là số, có lúc là chuỗi — chuẩn hoá trước khi so."""
    return _as_int(result_code) == MOMO_SUCCESS_CODE


def is_pending(result_code: object) -> bool:
    """Đơn đã tạo nhưng người dùng CHƯA xác nhận thanh toán.

    Phải phân biệt với thất bại. Người dùng đang dở tay quét QR mà lỡ quay về
    app thì `/query` trả 1000 — đánh dấu đơn là Failed lúc đó là **giết oan**:
    họ trả tiền xong, IPN về, nhưng đơn đã mang trạng thái hỏng.
    """
    return _as_int(result_code) == MOMO_PENDING_CODE


def _as_int(value: object) -> int | None:
    try:
        return int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


async def create_payment(
    *, amount: int, order_id: str, order_info: str, redirect_url: str, ipn_url: str
) -> dict:
    """Gọi MoMo tạo đơn. Trả về JSON thô (có `payUrl`, `deeplink`, `qrCodeUrl`)."""
    body = build_create_body(
        amount=amount,
        order_id=order_id,
        order_info=order_info,
        redirect_url=redirect_url,
        ipn_url=ipn_url,
    )
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(settings.MOMO_CREATE_URL, json=body)

    data = response.json()
    logger.info(
        "MoMo tạo đơn %s → resultCode=%s (%s)",
        order_id, data.get("resultCode"), data.get("message"),
    )
    return data


async def query_payment(order_id: str) -> dict:
    """Hỏi MoMo trạng thái thật của một đơn.

    **Đây là nguồn sự thật**, không phải tham số trên URL redirect. Người dùng có
    thể tự sửa URL trong WebView; MoMo thì không nói dối.
    """
    async with httpx.AsyncClient(timeout=20) as client:
        response = await client.post(settings.MOMO_QUERY_URL, json=build_query_body(order_id))

    data = response.json()
    logger.info(
        "MoMo tra cứu đơn %s → resultCode=%s (%s)",
        order_id, data.get("resultCode"), data.get("message"),
    )
    return data
