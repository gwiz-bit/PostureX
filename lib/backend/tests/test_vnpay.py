"""Test ký/xác minh chữ ký VNPay — hàm thuần, không cần sandbox hay mạng."""

import urllib.parse
from datetime import datetime

from app.services.vnpay import (
    VN_TZ,
    build_payment_url,
    is_successful,
    verify_signature,
)

SECRET = "TESTSECRET123"
COMMON = {
    "pay_url": "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html",
    "tmn_code": "DEMOTMN",
    "hash_secret": SECRET,
    "amount_vnd": 99000,
    "txn_ref": "42",
    "order_info": "Nang cap goi Premium",
    "return_url": "http://10.0.2.2:9000/api/v1/payments/vnpay/return",
    "client_ip": "127.0.0.1",
    "created_at": datetime(2026, 7, 12, 10, 30, 0, tzinfo=VN_TZ),
}


def _params_from_url(url: str) -> dict[str, str]:
    query = urllib.parse.urlparse(url).query
    return dict(urllib.parse.parse_qsl(query))


def test_amount_is_multiplied_by_100():
    """VNPay nhận đơn vị nhỏ nhất — 99.000đ phải gửi đi là 9900000."""
    params = _params_from_url(build_payment_url(**COMMON))
    assert params["vnp_Amount"] == "9900000"


def test_create_date_uses_vietnam_time():
    params = _params_from_url(build_payment_url(**COMMON))
    assert params["vnp_CreateDate"] == "20260712103000"
    assert params["vnp_ExpireDate"] == "20260712104500"  # +15 phút


def test_url_we_build_verifies_against_our_own_checker():
    """Chữ ký ta ký ra phải tự xác minh lại được — bắt lỗi lệch encode giữa
    lúc ký và lúc kiểm tra (nguyên nhân phổ biến nhất của 'Chữ ký không hợp lệ')."""
    params = _params_from_url(build_payment_url(**COMMON))
    assert verify_signature(params, SECRET) is True


def test_tampered_amount_is_rejected():
    """Sửa số tiền trên URL rồi gửi lại thì chữ ký phải fail."""
    params = _params_from_url(build_payment_url(**COMMON))
    params["vnp_Amount"] = "100"
    assert verify_signature(params, SECRET) is False


def test_wrong_secret_is_rejected():
    params = _params_from_url(build_payment_url(**COMMON))
    assert verify_signature(params, "SAI-SECRET") is False


def test_missing_hash_is_rejected():
    params = _params_from_url(build_payment_url(**COMMON))
    del params["vnp_SecureHash"]
    assert verify_signature(params, SECRET) is False


def test_non_vnp_params_do_not_break_signature():
    """Tham số lạ (không có tiền tố vnp_) không được tham gia ký."""
    params = _params_from_url(build_payment_url(**COMMON))
    params["utm_source"] = "facebook"
    assert verify_signature(params, SECRET) is True


def test_is_successful_requires_both_codes():
    assert is_successful({"vnp_ResponseCode": "00", "vnp_TransactionStatus": "00"}) is True
    # Thanh toán báo OK nhưng giao dịch bị huỷ -> KHÔNG được coi là thành công.
    assert is_successful({"vnp_ResponseCode": "00", "vnp_TransactionStatus": "02"}) is False
    assert is_successful({"vnp_ResponseCode": "24", "vnp_TransactionStatus": "00"}) is False
    assert is_successful({}) is False
