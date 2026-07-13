"""Cấu hình slowapi dùng chung — 1 Limiter instance duy nhất để cả
app/main.py (đăng ký exception handler) và các route (áp decorator) cùng
tham chiếu, tránh vòng import."""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
