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
