"""Ký và xác minh chữ ký VNPay.

Toàn bộ file này là **hàm thuần**: không chạm DB, không gọi mạng — nhờ vậy
unit test được mà không cần sandbox VNPay (xem tests/test_vnpay.py).

Quy tắc ký của VNPay (sai một bước là báo "Chữ ký không hợp lệ"):
  1. Bỏ `vnp_SecureHash` và `vnp_SecureHashType` ra khỏi tập tham số.
  2. Sắp xếp các key còn lại theo thứ tự alphabet.
  3. Nối thành `key=urlencode(value)&key=urlencode(value)...` — value phải
     encode bằng quote_plus (dấu cách thành `+`).
  4. HMAC-SHA512 chuỗi đó bằng HashSecret, kết quả hex thường.
Chuỗi đem ký và chuỗi đặt lên URL là **một** — không được encode khác nhau.
"""

import hashlib
import hmac
import urllib.parse
from datetime import datetime, timedelta, timezone

# VNPay chốt mọi mốc thời gian theo giờ Việt Nam, không phải UTC.
VN_TZ = timezone(timedelta(hours=7))

# Mã phản hồi "giao dịch thành công" của VNPay.
VNPAY_SUCCESS_CODE = "00"


def _hmac_sha512(secret: str, data: str) -> str:
    return hmac.new(
        secret.encode("utf-8"), data.encode("utf-8"), hashlib.sha512
    ).hexdigest()


def _build_signing_string(params: dict[str, str]) -> str:
    """Chuỗi dùng để ký: sort theo key, value encode bằng quote_plus."""
    return "&".join(
        f"{key}={urllib.parse.quote_plus(str(params[key]))}" for key in sorted(params)
    )


def build_payment_url(
    *,
    pay_url: str,
    tmn_code: str,
    hash_secret: str,
    amount_vnd: int,
    txn_ref: str,
    order_info: str,
    return_url: str,
    client_ip: str,
    created_at: datetime | None = None,
    expire_minutes: int = 15,
) -> str:
    """Dựng URL thanh toán VNPay đã ký.

    [amount_vnd] là số tiền VNĐ *thật* (vd 99000). VNPay nhận đơn vị nhỏ nhất
    nên phải nhân 100 — quên bước này thì người dùng bị tính sai 100 lần.
    """
    now = created_at or datetime.now(VN_TZ)

    params: dict[str, str] = {
        "vnp_Version": "2.1.0",
        "vnp_Command": "pay",
        "vnp_TmnCode": tmn_code,
        "vnp_Amount": str(amount_vnd * 100),
        "vnp_CurrCode": "VND",
        "vnp_TxnRef": txn_ref,
        "vnp_OrderInfo": order_info,
        "vnp_OrderType": "other",
        "vnp_Locale": "vn",
        "vnp_ReturnUrl": return_url,
        "vnp_IpAddr": client_ip,
        "vnp_CreateDate": now.strftime("%Y%m%d%H%M%S"),
        "vnp_ExpireDate": (now + timedelta(minutes=expire_minutes)).strftime("%Y%m%d%H%M%S"),
    }

    query = _build_signing_string(params)
    secure_hash = _hmac_sha512(hash_secret, query)
    return f"{pay_url}?{query}&vnp_SecureHash={secure_hash}"


def verify_signature(params: dict[str, str], hash_secret: str) -> bool:
    """Kiểm tra chữ ký của dữ liệu VNPay trả về (ReturnUrl hoặc IPN).

    [params] là toàn bộ query string VNPay gửi sang, gồm cả `vnp_SecureHash`.
    Chỉ các key bắt đầu bằng `vnp_` mới tham gia ký — tham số lạ bị bỏ qua.
    """
    received_hash = params.get("vnp_SecureHash", "")
    if not received_hash:
        return False

    signed_params = {
        key: value
        for key, value in params.items()
        if key.startswith("vnp_") and key not in ("vnp_SecureHash", "vnp_SecureHashType")
    }
    expected = _hmac_sha512(hash_secret, _build_signing_string(signed_params))

    # compare_digest thay vì `==` để không rò rỉ thông tin qua thời gian so sánh.
    return hmac.compare_digest(expected, received_hash)


def is_successful(params: dict[str, str]) -> bool:
    """True nếu VNPay báo giao dịch thành công.

    Phải kiểm tra **cả hai** mã: `vnp_ResponseCode` (kết quả thanh toán) và
    `vnp_TransactionStatus` (trạng thái giao dịch). Chỉ xem một mã là chưa đủ —
    có trường hợp thanh toán được ghi nhận nhưng giao dịch vẫn bị huỷ.
    """
    return (
        params.get("vnp_ResponseCode") == VNPAY_SUCCESS_CODE
        and params.get("vnp_TransactionStatus") == VNPAY_SUCCESS_CODE
    )
