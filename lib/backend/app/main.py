"""Entry point ứng dụng FastAPI Posture X."""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.rate_limit import limiter

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)

app = FastAPI(
    title=settings.APP_NAME,
    description="AI-powered gym technique analysis backend",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# Rate limiting (slowapi) — dung cho /auth/forgot-password de chong spam
# email/do email dang ky nguoi dung.
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS mở cho Flutter dev (thu hẹp origins trong production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)

# Video hướng dẫn bài tập do admin upload — serve công khai (không cần
# đăng nhập), khác với storage/videos (video tập luyện riêng tư của user,
# không mount static vì không nên public).
app.mount(
    "/media/exercise-videos",
    StaticFiles(directory=str(settings.get_exercise_video_storage_path())),
    name="exercise-videos",
)


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    """Kiểm tra trạng thái server."""
    return {"status": "ok", "app": settings.APP_NAME}
