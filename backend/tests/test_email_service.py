"""Retry khi gửi email SMTP gặp lỗi tạm thời — khoá lại lỗi phát hiện qua log
production thật (05-06/10/2026): Gmail thỉnh thoảng đóng kết nối giữa chừng
("Connection unexpectedly closed" / SMTPServerDisconnected) dù tài khoản và
mật khẩu đúng, khiến đăng ký/quên-mật-khẩu thất bại dù không có gì sai về cấu
hình — một lần thất bại là tester không nhận được OTP, không thử lại được.
"""

import smtplib

import pytest

from app.core.config import settings
from app.services import email_service


@pytest.fixture(autouse=True)
def _smtp_configured(monkeypatch):
    monkeypatch.setattr(settings, "SMTP_USER", "bot@example.com")
    monkeypatch.setattr(settings, "SMTP_PASSWORD", "app-password")
    monkeypatch.setattr(email_service, "_RETRY_DELAYS_SECONDS", (0, 0))


def _fake_send(side_effects: list):
    calls = {"n": 0}

    def fake(_to_email, _subject, _body):
        idx = calls["n"]
        calls["n"] += 1
        effect = side_effects[idx]
        if isinstance(effect, Exception):
            raise effect
        return effect

    return fake, calls


@pytest.mark.asyncio
async def test_loi_tam_thoi_duoc_thu_lai_va_thanh_cong(monkeypatch) -> None:
    """ĐỎ trên code cũ: 2 lần đầu lỗi kết nối, lần 3 thành công — phải gửi
    được, không raise, đúng số lần thử lại như log production cho thấy cần."""
    fake, calls = _fake_send([
        smtplib.SMTPServerDisconnected("Connection unexpectedly closed"),
        smtplib.SMTPServerDisconnected("Connection unexpectedly closed"),
        None,
    ])
    monkeypatch.setattr(email_service, "_send_once", fake)

    await email_service.send_otp_email("tester@posturex.com", "123456")

    assert calls["n"] == 3


@pytest.mark.asyncio
async def test_het_so_lan_thu_van_loi_thi_raise(monkeypatch) -> None:
    """Không nuốt lỗi âm thầm: lỗi kết nối lặp lại hết số lần cho phép thì
    phải raise để route trả lỗi rõ ràng cho client, không báo thành công giả."""
    fake, calls = _fake_send([
        smtplib.SMTPServerDisconnected("Connection unexpectedly closed"),
        smtplib.SMTPServerDisconnected("Connection unexpectedly closed"),
        smtplib.SMTPServerDisconnected("Connection unexpectedly closed"),
    ])
    monkeypatch.setattr(email_service, "_send_once", fake)

    with pytest.raises(smtplib.SMTPServerDisconnected):
        await email_service.send_otp_email("tester@posturex.com", "123456")

    assert calls["n"] == 3


@pytest.mark.asyncio
async def test_thanh_cong_ngay_lan_dau_khong_can_thu_lai(monkeypatch) -> None:
    """Hồi quy: trường hợp bình thường (không lỗi) vẫn chỉ gửi đúng 1 lần."""
    fake, calls = _fake_send([None])
    monkeypatch.setattr(email_service, "_send_once", fake)

    await email_service.send_reset_password_email("tester@posturex.com", "token-abc")

    assert calls["n"] == 1


@pytest.mark.asyncio
async def test_loi_khong_thuoc_danh_sach_retry_thi_raise_ngay(monkeypatch) -> None:
    """Lỗi xác thực (sai mật khẩu ứng dụng) không nằm trong _RETRYABLE_ERRORS —
    thử lại không giải quyết được gì, nên phải raise ngay từ lần đầu."""
    fake, calls = _fake_send([
        smtplib.SMTPAuthenticationError(535, b"Bad credentials"),
    ])
    monkeypatch.setattr(email_service, "_send_once", fake)

    with pytest.raises(smtplib.SMTPAuthenticationError):
        await email_service.send_otp_email("tester@posturex.com", "123456")

    assert calls["n"] == 1
