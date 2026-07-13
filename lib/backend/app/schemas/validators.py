"""Validator Pydantic dùng chung giữa các schema — tránh lặp lại logic
kiểm tra độ mạnh mật khẩu ở nhiều nơi (reset-password, đổi mật khẩu khi
đã đăng nhập...)."""

import re


def validate_password_strength(v: str) -> str:
    if len(v) < 8:
        raise ValueError("Mật khẩu phải có ít nhất 8 ký tự.")
    if not re.search(r"[A-Z]", v):
        raise ValueError("Mật khẩu phải có ít nhất 1 chữ hoa.")
    if not re.search(r"[a-z]", v):
        raise ValueError("Mật khẩu phải có ít nhất 1 chữ thường.")
    if not re.search(r"\d", v):
        raise ValueError("Mật khẩu phải có ít nhất 1 chữ số.")
    if not re.search(r"[^A-Za-z0-9]", v):
        raise ValueError("Mật khẩu phải có ít nhất 1 ký tự đặc biệt.")
    return v
