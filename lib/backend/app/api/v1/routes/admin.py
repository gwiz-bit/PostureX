"""Admin endpoints — chỉ user có is_admin=True mới truy cập được."""

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import admin as admin_crud
from app.crud.user import get_user_by_id
from app.crud.video import get_video_by_id
from app.models.user import User
from app.schemas.admin import AIConfig, AdminUserOut, AdminUserUpdate, SystemStats
from app.services.video_service import video_service
from app.utils.deps import get_current_admin

router = APIRouter(prefix="/admin", tags=["admin"])

# ─────────────────────────────────────────────
# Cấu hình AI (lưu trong bộ nhớ, reset khi restart)
# ─────────────────────────────────────────────
_ai_config = AIConfig()


# ─────────────────────────────────────────────
# Thống kê toàn hệ thống
# ─────────────────────────────────────────────

@router.get("/stats", response_model=SystemStats)
async def get_stats(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> SystemStats:
    """Xem thống kê toàn hệ thống: user, video, workout, tổng rep."""
    data = await admin_crud.get_system_stats(db)
    return SystemStats(**data)


# ─────────────────────────────────────────────
# Quản lý người dùng
# ─────────────────────────────────────────────

@router.get("/users", response_model=list[AdminUserOut])
async def list_users(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[AdminUserOut]:
    """Danh sách tất cả user trong hệ thống."""
    users = await admin_crud.get_all_users(db, skip=skip, limit=limit)
    return [AdminUserOut.model_validate(u) for u in users]


@router.patch("/users/{user_id}", response_model=AdminUserOut)
async def update_user(
    user_id: int,
    data: AdminUserUpdate,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
) -> AdminUserOut:
    """Cập nhật thông tin user: kích hoạt/vô hiệu, cấp/thu quyền admin."""
    if user_id == current_admin.id and data.is_admin is False:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không thể tự thu hồi quyền admin của chính mình.",
        )
    user = await get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy user.")
    updated = await admin_crud.update_user_by_admin(db, user, data)
    return AdminUserOut.model_validate(updated)


@router.delete("/users/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(
    user_id: int,
    db: AsyncSession = Depends(get_db),
    current_admin: User = Depends(get_current_admin),
) -> None:
    """Xóa tài khoản người dùng (và toàn bộ video/workout của họ)."""
    if user_id == current_admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không thể xóa tài khoản admin đang đăng nhập.",
        )
    user = await get_user_by_id(db, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy user.")
    await admin_crud.delete_user(db, user)


# ─────────────────────────────────────────────
# Quản lý bài tập (workout)
# ─────────────────────────────────────────────

@router.get("/workouts")
async def list_all_workouts(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[dict]:
    """Xem tất cả buổi tập của mọi user."""
    workouts = await admin_crud.get_all_workouts(db, skip=skip, limit=limit)
    return [
        {
            "id": w.id,
            "user_id": w.user_id,
            "exercise": w.exercise,
            "total_reps": w.total_reps,
            "accuracy_score": w.accuracy_score,
            "duration_seconds": w.duration_seconds,
            "started_at": w.started_at,
            "created_at": w.created_at,
        }
        for w in workouts
    ]


@router.delete("/workouts/{workout_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_workout(
    workout_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> None:
    """Xóa một buổi tập."""
    from sqlalchemy import select
    from app.models.workout import Workout
    result = await db.execute(select(Workout).where(Workout.id == workout_id))
    workout = result.scalar_one_or_none()
    if workout is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy buổi tập.")
    await admin_crud.delete_workout(db, workout)


# ─────────────────────────────────────────────
# Quản lý video
# ─────────────────────────────────────────────

@router.get("/videos")
async def list_all_videos(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[dict]:
    """Xem tất cả video của mọi user."""
    from sqlalchemy import select
    from app.models.video import Video
    result = await db.execute(
        select(Video).order_by(Video.created_at.desc()).offset(skip).limit(limit)
    )
    videos = result.scalars().all()
    return [
        {
            "id": v.id,
            "user_id": v.user_id,
            "exercise": v.exercise,
            "original_filename": v.original_filename,
            "total_reps": v.total_reps,
            "accuracy_score": v.accuracy_score,
            "created_at": v.created_at,
        }
        for v in videos
    ]


@router.delete("/videos/{video_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_video(
    video_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> None:
    """Xóa video (file vật lý + bản ghi DB)."""
    from sqlalchemy import select
    from app.models.video import Video
    result = await db.execute(select(Video).where(Video.id == video_id))
    vid = result.scalar_one_or_none()
    if vid is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy video.")
    await video_service.delete_file(vid)
    await db.delete(vid)


# ─────────────────────────────────────────────
# Quản lý cấu hình AI
# ─────────────────────────────────────────────

@router.get("/config", response_model=AIConfig)
async def get_ai_config(
    _: User = Depends(get_current_admin),
) -> AIConfig:
    """Xem cấu hình hiện tại của model AI và ngưỡng phân tích."""
    return _ai_config


@router.patch("/config", response_model=AIConfig)
async def update_ai_config(
    data: AIConfig,
    _: User = Depends(get_current_admin),
) -> AIConfig:
    """Cập nhật ngưỡng phân tích AI (áp dụng ngay cho các phiên mới)."""
    global _ai_config
    _ai_config = data

    # Cập nhật ngưỡng cho SquatAnalyzer
    from app.ml.analyzers import squat as squat_module
    squat_module.KNEE_DEPTH_THRESHOLD = data.squat_knee_depth_threshold
    squat_module.BACK_STRAIGHT_MIN = data.squat_back_straight_min
    squat_module.KNEE_OVERSHOOT_RATIO = data.squat_knee_overshoot_ratio

    return _ai_config
