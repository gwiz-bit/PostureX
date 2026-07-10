"""Entry point ứng dụng FastAPI Posture X."""

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import settings

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

# CORS mở cho Flutter dev (thu hẹp origins trong production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    """Kiểm tra trạng thái server."""
    return {"status": "ok", "app": settings.APP_NAME}
