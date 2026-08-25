"""Entry point ứng dụng FastAPI Posture X."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from slowapi.errors import RateLimitExceeded

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.rate_limit import limiter, rate_limit_handler
from app.core.scheduler import shutdown_scheduler, start_scheduler
from app.models.user import User
from app.utils.deps import get_current_user

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    """Bật scheduler (nhắc nghỉ giải lao, tổng kết hằng ngày) theo vòng đời app."""
    start_scheduler()
    try:
        yield
    finally:
        shutdown_scheduler()


app = FastAPI(
    title=settings.APP_NAME,
    description="AI-powered gym technique analysis backend",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Rate limiting (slowapi) — chong spam email o /auth/forgot-password va chong
# do mat khau o /auth/login.
#
# Dung `rate_limit_handler` cua rieng minh thay cho handler mac dinh cua slowapi:
# handler mac dinh tra {"error": "..."} tieng Anh, ma app Flutter chi doc khoa
# "detail" nen se hien cau chung chung "Something went wrong". Xem chu thich
# day du trong app/core/rate_limit.py.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_handler)

# CORS — mặc định chỉ mở cho localhost (Flutter web lúc dev). Production khai
# báo origin thật qua ALLOWED_ORIGINS trong .env; xem chú thích ở config.py về
# lý do không được dùng ["*"].
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_origin_regex=settings.ALLOWED_ORIGIN_REGEX or None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

# Video hướng dẫn bài tập do admin upload — bất kỳ user đã đăng nhập nào
# cũng xem được (không giới hạn theo quyền), nhưng khác StaticFiles cũ ở
# chỗ không còn public hoàn toàn ra Internet: nhiều video trong thư viện
# là nội dung có bản quyền mua từ bên thứ ba (vd MoveKit), license không
# chắc cho phép phát tán file gốc qua URL công khai không cần đăng nhập —
# yêu cầu Bearer token giảm rủi ro đó (giống storage/videos, vốn cũng
# chưa từng public).
@app.get("/media/exercise-videos/{filename}")
async def get_exercise_video(
    filename: str,
    current_user: User = Depends(get_current_user),
) -> FileResponse:
    storage_dir = settings.get_exercise_video_storage_path().resolve()
    file_path = (storage_dir / filename).resolve()
    if storage_dir not in file_path.parents or not file_path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy video.")
    return FileResponse(file_path)


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    """Kiểm tra trạng thái server."""
    return {"status": "ok", "app": settings.APP_NAME}
