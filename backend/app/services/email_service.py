"""Gửi email qua SMTP (Gmail). smtplib là thư viện đồng bộ nên chạy trong
thread pool để không chặn event loop async."""

import asyncio
import logging
import smtplib
import time
from email.mime.text import MIMEText

from app.core.config import settings

logger = logging.getLogger(__name__)

_PLACEHOLDER = "youraccount@gmail.com"

# Phát hiện qua log production thật (05-06/10/2026): SMTP tới Gmail thỉnh
# thoảng báo "Connection unexpectedly closed" (SMTPServerDisconnected) dù
# tài khoản/mật khẩu đúng — lỗi mạng/Gmail tạm thời, không phải lỗi cấu hình,
# nên retry ngắn là đủ (khớp lỗi 503 tạm thời của Gemini đã xử lý tương tự
# trong ai_coach_service.py). KHÔNG dùng OSError trần: mọi lỗi của smtplib
# (kể cả SMTPAuthenticationError — sai mật khẩu ứng dụng, thử lại vô ích)
# đều kế thừa từ OSError trong Python 3, nên liệt kê đích danh từng lỗi
# cấp kết nối/giao thức thay vì bắt rộng.
_MAX_ATTEMPTS = 3
_RETRY_DELAYS_SECONDS = (1, 3)
_RETRYABLE_ERRORS = (
    smtplib.SMTPServerDisconnected,
    smtplib.SMTPConnectError,
    smtplib.SMTPHeloError,
    TimeoutError,
    ConnectionError,
)


def _smtp_configured() -> bool:
    """Trả về True khi SMTP đã được điền thông tin thật (không phải placeholder)."""
    return bool(settings.SMTP_USER) and settings.SMTP_USER != _PLACEHOLDER


def _send_once(to_email: str, subject: str, body: str) -> None:
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_USER}>"
    msg["To"] = to_email

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.send_message(msg)


def _send_sync(to_email: str, subject: str, body: str) -> None:
    for attempt in range(_MAX_ATTEMPTS):
        try:
            _send_once(to_email, subject, body)
            return
        except _RETRYABLE_ERRORS as e:
            if attempt == _MAX_ATTEMPTS - 1:
                logger.error(
                    "Gửi email tới %s thất bại sau %d lần thử: %s", to_email, _MAX_ATTEMPTS, e
                )
                raise
            logger.warning(
                "Gửi email tới %s lỗi tạm thời (lần %d/%d): %s — thử lại",
                to_email, attempt + 1, _MAX_ATTEMPTS, e,
            )
            time.sleep(_RETRY_DELAYS_SECONDS[attempt])


async def send_otp_email(to_email: str, otp_code: str) -> None:
    """Gửi mã OTP xác thực đăng ký tới email người dùng.

    Khi SMTP chưa cấu hình (môi trường dev), in OTP ra log thay vì gửi email
    để không chặn luồng đăng ký.
    """
    if not _smtp_configured():
        logger.warning(
            "[DEV] SMTP chưa cấu hình — OTP cho %s là: %s", to_email, otp_code
        )
        return
    subject = "Posture X - Mã xác thực đăng ký"
    body = (
        f"Mã xác thực (OTP) của bạn là: {otp_code}\n\n"
        f"Mã có hiệu lực trong {settings.OTP_EXPIRE_MINUTES} phút.\n"
        "Nếu bạn không yêu cầu đăng ký tài khoản Posture X, vui lòng bỏ qua email này."
    )
    await asyncio.to_thread(_send_sync, to_email, subject, body)


async def send_reset_password_email(to_email: str, reset_token: str) -> None:
    """Gửi token đặt lại mật khẩu tới email người dùng.

    Ứng dụng là app di động thuần (chưa có web/deep-link), nên thay vì
    một link bấm được, email chứa thẳng token dạng text để người dùng
    copy vào màn "Reset password" trong app — vẫn cùng token bảo mật
    (secrets.token_urlsafe) như thiết kế gốc, chỉ khác cách truyền tay.
    """
    subject = "Posture X - Đặt lại mật khẩu"
    body = (
        f"Mã đặt lại mật khẩu của bạn là:\n\n{reset_token}\n\n"
        "Mở app Posture X, vào màn 'Reset password', dán mã này để đặt mật khẩu mới.\n"
        f"Mã có hiệu lực trong {settings.RESET_TOKEN_EXPIRE_MINUTES} phút.\n"
        "Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này — "
        "mật khẩu hiện tại của bạn vẫn an toàn."
    )
    await asyncio.to_thread(_send_sync, to_email, subject, body)


async def send_password_changed_email(to_email: str) -> None:
    """Thông báo mật khẩu vừa được đổi thành công — giúp người dùng phát
    hiện sớm nếu có ai đó khác thực hiện thay đổi này mà không phải họ."""
    subject = "Posture X - Mật khẩu đã được thay đổi"
    body = (
        "Mật khẩu tài khoản Posture X của bạn vừa được đặt lại thành công.\n\n"
        "Nếu đây không phải là bạn, vui lòng liên hệ hỗ trợ ngay lập tức."
    )
    await asyncio.to_thread(_send_sync, to_email, subject, body)


async def send_account_deletion_email(to_email: str, code: str, expire_minutes: int) -> None:
    """Gửi mã xác nhận xoá tài khoản (luồng web /delete-account).

    Khi SMTP chưa cấu hình (môi trường dev), in mã ra log thay vì gửi email.
    """
    if not _smtp_configured():
        logger.warning("[DEV] SMTP chưa cấu hình — mã xoá tài khoản cho %s là: %s", to_email, code)
        return
    subject = "Posture X - Xác nhận xoá tài khoản"
    body = (
        f"Mã xác nhận xoá tài khoản Posture X của bạn là: {code}\n\n"
        f"Mã có hiệu lực trong {expire_minutes} phút. Nhập mã này vào trang yêu cầu xoá "
        "tài khoản để hoàn tất. Khi xác nhận, tài khoản và dữ liệu của bạn sẽ bị xoá "
        "vĩnh viễn ngay lập tức và không thể khôi phục.\n\n"
        "Nếu bạn không yêu cầu xoá tài khoản, hãy bỏ qua email này — tài khoản của bạn "
        "vẫn nguyên vẹn."
    )
    await asyncio.to_thread(_send_sync, to_email, subject, body)
