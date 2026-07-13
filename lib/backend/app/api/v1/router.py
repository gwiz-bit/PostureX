"""Tổng hợp tất cả route v1."""

from fastapi import APIRouter

from app.api.v1.routes import admin, auth, exercises, realtime, subscriptions, users, videos, workouts

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(videos.router)
api_router.include_router(workouts.router)
api_router.include_router(realtime.router)
api_router.include_router(admin.router)
api_router.include_router(subscriptions.router)
api_router.include_router(exercises.router)
