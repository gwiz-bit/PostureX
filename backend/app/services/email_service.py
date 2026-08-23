"""Gửi email qua SMTP (Gmail). smtplib là thư viện đồng bộ nên chạy trong
thread pool để không chặn event loop async."""

import asyncio
import smtplib
from email.mime.text import MIMEText

from app.core.config import settings


def _send_sync(to_email: str, subject: str, body: str) -> None:
    msg = MIMEText(body, "plain", "utf-8")
    msg["Subject"] = subject
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_USER}>"
    msg["To"] = to_email

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=15) as server:
        server.starttls()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.send_message(msg)


async def send_otp_email(to_email: str, otp_code: str) -> None:
    """Gửi mã OTP xác thực đăng ký tới email người dùng."""
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
