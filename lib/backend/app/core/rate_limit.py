"""Cấu hình slowapi dùng chung — 1 Limiter instance duy nhất để cả
app/main.py (đăng ký exception handler) và các route (áp decorator) cùng
tham chiếu, tránh vòng import."""

import os
import time
import warnings

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

# `config_filename` KHÔNG được để None. Lý do nằm trong slowapi/extension.py:
#
#     dotenv_file_exists = os.path.isfile(".env")
#     self.app_config = Config(
#         ".env" if dotenv_file_exists and config_filename is None else config_filename
#     )
#
# slowapi tự nuốt file .env chỉ vì nó tồn tại, bằng starlette.config.Config —
# và Config mở file KHÔNG chỉ định encoding, nên Python dùng codec mặc định của
# hệ thống. Trên Windows tiếng Việt codec đó là cp1252, gặp comment tiếng Việt
# trong .env là server chết ngay lúc import, trước cả khi uvicorn kịp bind cổng:
#
#     UnicodeDecodeError: 'charmap' codec can't decode byte 0x81 in position 43
#
# Bug này chỉ hiện trên máy Windows dùng locale tiếng Việt, và chỉ khi chạy
# uvicorn từ thư mục lib/backend (chỗ có .env) — nên máy khác có thể không thấy.
# Cách né tạm là đặt PYTHONUTF8=1 trước khi chạy; đây là cách sửa thật.
#
# Trỏ sang os.devnull (không phải file thường trên cả Windows lẫn Linux) để
# Config bỏ qua việc đọc file. Không mất gì: slowapi chỉ dùng app_config để tìm
# các biến RATELIMIT_*, mà dự án không dùng biến nào trong số đó — cấu hình
# thật đọc qua app/core/config.py (pydantic-settings, đã khai báo
# env_file_encoding="utf-8" nên xử lý tiếng Việt đúng).
#
# KHÔNG bật `headers_enabled=True` — đã thử và nó làm hỏng mọi request thành
# công tới route có rate limit. Nhánh thành công của slowapi (extension.py:738):
#
#     response = await func(*args, **kwargs)
#     if not isinstance(response, Response):
#         self._inject_headers(kwargs.get("response"), ...)
#
# Endpoint ở đây trả Pydantic model (`TokenResponse`, `MessageResponse`) chứ
# không phải `Response`, nên slowapi đi tìm tham số tên `response` trong kwargs.
# Không có → `_inject_headers(None)` → `Exception: parameter 'response' must be
# an instance of starlette.responses.Response`. Muốn bật thì phải thêm
# `response: Response` vào chữ ký của TẤT CẢ endpoint có @limiter.limit.
#
# Không cần thiết: `rate_limit_handler` bên dưới tự tính và tự gắn Retry-After,
# chỉ trên response 429 — đúng chỗ client cần.
with warnings.catch_warnings():
    # Config cảnh báo "Config file not found" cho đường dẫn trên. Đúng ý đồ.
    warnings.simplefilter("ignore")
    limiter = Limiter(key_func=get_remote_address, config_filename=os.devnull)


def _format_wait(seconds: int) -> str:
    """Đổi số giây thành cụm tiếng Việt đọc được.

    Cùng một handler phục vụ hai mức giới hạn rất khác nhau — /auth/login là
    10/phút (chờ vài chục giây), /auth/forgot-password là 5/giờ (chờ gần một
    tiếng) — nên không thể chỉ in ra số giây.
    """
    if seconds < 60:
        return f"{seconds} giây"
    if seconds < 3600:
        return f"{round(seconds / 60)} phút"
    return f"{round(seconds / 3600)} giờ"


def _seconds_until_reset(request: Request) -> int | None:
    """Còn bao lâu nữa thì hạn mức được nạp lại, tính bằng giây.

    `request.state.view_rate_limit` do slowapi gắn vào trước khi ném lỗi, dạng
    (RateLimitItem, [khoá...]). `get_window_stats` trả (mốc-reset-epoch, số-lượt-còn).
    """
    current_limit = getattr(request.state, "view_rate_limit", None)
    if current_limit is None:
        return None
    try:
        reset_at, _remaining = limiter.limiter.get_window_stats(current_limit[0], *current_limit[1])
    except Exception:
        # Không lấy được thì thôi, vẫn trả thông báo chung — không để việc
        # dựng câu thông báo làm hỏng nốt response lỗi.
        return None
    return max(1, int(reset_at - time.time()) + 1)


def rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """Trả 429 với thân `{"detail": ...}` bằng tiếng Việt.

    Handler mặc định của slowapi (`_rate_limit_exceeded_handler`) trả
    `{"error": "Rate limit exceeded: 10 per 1 minute"}` — khoá là `error`, nội
    dung tiếng Anh. App Flutter chỉ đọc khoá `detail` (xem `_decode` trong
    lib/services/api_client.dart), không khớp nên rơi vào câu mặc định
    "Something went wrong. Please try again." — người dùng bị chặn mà không
    hiểu vì sao và phải chờ bao lâu.

    Vẫn giữ status 429, và tự gắn `Retry-After` (giây) để client biết chờ bao
    lâu — không gọi `_inject_headers` của slowapi vì hàm đó không làm gì khi
    `headers_enabled=False`; xem lý do không bật cờ đó ở phần khởi tạo Limiter.
    """
    wait = _seconds_until_reset(request)
    if wait is None:
        detail = "Bạn đã thao tác quá nhiều lần. Vui lòng chờ một lát rồi thử lại."
    else:
        detail = f"Bạn đã thao tác quá nhiều lần. Vui lòng thử lại sau {_format_wait(wait)}."

    headers = {"Retry-After": str(wait)} if wait is not None else None
    return JSONResponse(status_code=429, content={"detail": detail}, headers=headers)
