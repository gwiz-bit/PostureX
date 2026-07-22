"""Admin endpoints — chỉ user có is_admin=True mới truy cập được."""

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import admin as admin_crud
from app.crud import exercise as exercise_crud
from app.crud import subscription as sub_crud
from app.crud.user import get_user_by_id
from app.crud.video import get_video_by_id
from app.models.user import User
from app.schemas.admin import AIConfig, AdminUserOut, AdminUserUpdate, SystemStats
from app.schemas.exercise import ExerciseCreate, ExerciseOut, ExerciseUpdate
from app.schemas.subscription import (
    NotificationCreate,
    NotificationOut,
    PlanCreate,
    PlanOut,
    PlanUpdate,
    PromoCodeCreate,
    PromoCodeOut,
    PromoCodeUpdate,
    RevenueStats,
)
from app.services.exercise_video_service import exercise_video_service
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


# ─────────────────────────────────────────────
# Quản lý gói subscription (Plans)
# ─────────────────────────────────────────────

@router.get("/plans", response_model=list[PlanOut])
async def admin_list_plans(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[PlanOut]:
    """Xem tất cả gói (kể cả gói đã ngừng bán)."""
    plans = await sub_crud.get_all_plans(db)
    return [PlanOut.model_validate(p) for p in plans]


@router.post("/plans", response_model=PlanOut, status_code=status.HTTP_201_CREATED)
async def admin_create_plan(
    data: PlanCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> PlanOut:
    """Tạo gói subscription mới."""
    plan = await sub_crud.create_plan(db, data)
    return PlanOut.model_validate(plan)


@router.patch("/plans/{plan_id}", response_model=PlanOut)
async def admin_update_plan(
    plan_id: int,
    data: PlanUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> PlanOut:
    """Cập nhật gói (giá, tính năng, ngừng/mở bán...)."""
    plan = await sub_crud.get_plan_by_id(db, plan_id)
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy gói.")
    updated = await sub_crud.update_plan(db, plan, data)
    return PlanOut.model_validate(updated)


@router.delete("/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_plan(
    plan_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> None:
    """Xóa gói subscription."""
    plan = await sub_crud.get_plan_by_id(db, plan_id)
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy gói.")
    await sub_crud.delete_plan(db, plan)


# ─────────────────────────────────────────────
# Quản lý mã giảm giá (PromoCodes)
# ─────────────────────────────────────────────

@router.get("/promo-codes", response_model=list[PromoCodeOut])
async def admin_list_promo_codes(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[PromoCodeOut]:
    """Xem tất cả mã giảm giá."""
    promos = await sub_crud.get_all_promo_codes(db)
    return [PromoCodeOut.model_validate(p) for p in promos]


@router.post("/promo-codes", response_model=PromoCodeOut, status_code=status.HTTP_201_CREATED)
async def admin_create_promo_code(
    data: PromoCodeCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> PromoCodeOut:
    """Tạo mã giảm giá mới."""
    promo = await sub_crud.create_promo_code(db, data)
    return PromoCodeOut.model_validate(promo)


@router.patch("/promo-codes/{promo_id}", response_model=PromoCodeOut)
async def admin_update_promo_code(
    promo_id: int,
    data: PromoCodeUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> PromoCodeOut:
    """Cập nhật mã giảm giá (vô hiệu hóa, đổi hạn dùng...)."""
    promo = await sub_crud.get_promo_by_id(db, promo_id)
    if promo is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy mã giảm giá.")
    updated = await sub_crud.update_promo_code(db, promo, data)
    return PromoCodeOut.model_validate(updated)


@router.delete("/promo-codes/{promo_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_promo_code(
    promo_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> None:
    """Xóa mã giảm giá."""
    promo = await sub_crud.get_promo_by_id(db, promo_id)
    if promo is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy mã giảm giá.")
    await sub_crud.delete_promo_code(db, promo)


# ─────────────────────────────────────────────
# Doanh thu (Revenue)
# ─────────────────────────────────────────────

@router.get("/revenue", response_model=RevenueStats)
async def admin_get_revenue(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> RevenueStats:
    """Thống kê doanh thu: tổng, theo gói, giao dịch gần nhất."""
    data = await sub_crud.get_revenue_stats(db)
    return RevenueStats(**data)


# ─────────────────────────────────────────────
# Thông báo (Notifications)
# ─────────────────────────────────────────────

@router.get("/notifications", response_model=list[NotificationOut])
async def admin_list_notifications(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[NotificationOut]:
    """Xem tất cả thông báo admin đã gửi."""
    notifs = await sub_crud.get_all_notifications(db)
    return [NotificationOut.model_validate(n) for n in notifs]


@router.post("/notifications", response_model=NotificationOut, status_code=status.HTTP_201_CREATED)
async def admin_create_notification(
    data: NotificationCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> NotificationOut:
    """Gửi thông báo broadcast mới (all/premium/free)."""
    notif = await sub_crud.create_notification(db, data)
    return NotificationOut.model_validate(notif)


# ─────────────────────────────────────────────
# Quản lý thư viện bài tập (Exercises)
# ─────────────────────────────────────────────

@router.get("/exercises", response_model=list[ExerciseOut])
async def admin_list_exercises(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[ExerciseOut]:
    """Xem tất cả bài tập (kể cả đã ẩn/draft)."""
    exercises = await exercise_crud.get_all_exercises(db)
    return [ExerciseOut.model_validate(e) for e in exercises]


@router.post("/exercises", response_model=ExerciseOut, status_code=status.HTTP_201_CREATED)
async def admin_create_exercise(
    data: ExerciseCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseOut:
    """Thêm bài tập mới vào thư viện."""
    exercise = await exercise_crud.create_exercise(db, data)
    return ExerciseOut.model_validate(exercise)


@router.patch("/exercises/{exercise_id}", response_model=ExerciseOut)
async def admin_update_exercise(
    exercise_id: int,
    data: ExerciseUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseOut:
    """Cập nhật bài tập (đổi trạng thái published/draft, mô tả, độ khó...)."""
    exercise = await exercise_crud.get_exercise_by_id(db, exercise_id)
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy bài tập.")
    updated = await exercise_crud.update_exercise(db, exercise, data)
    return ExerciseOut.model_validate(updated)


@router.delete("/exercises/{exercise_id}", status_code=status.HTTP_204_NO_CONTENT)
async def admin_delete_exercise(
    exercise_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> None:
    """Xóa bài tập khỏi thư viện."""
    exercise = await exercise_crud.get_exercise_by_id(db, exercise_id)
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy bài tập.")
    await exercise_crud.delete_exercise(db, exercise)


@router.post("/exercises/{exercise_id}/video", response_model=ExerciseOut)
async def admin_upload_exercise_video(
    exercise_id: int,
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseOut:
    """Upload video hướng dẫn cho 1 bài tập — video này sẽ hiện lên cho
    mọi user khi họ tập bài đó (thay thế video mẫu cứng trong app nếu có)."""
    exercise = await exercise_crud.get_exercise_by_id(db, exercise_id)
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy bài tập.")

    try:
        new_url = await exercise_video_service.save(file)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    # Xóa file cũ (nếu có) sau khi file mới đã lưu thành công, tránh rác
    # tích tụ mỗi lần admin đổi video cho cùng 1 bài tập.
    old_url = exercise.demo_video_url
    exercise.demo_video_url = new_url
    await db.flush()
    exercise_video_service.delete_by_url(old_url)

    return ExerciseOut.model_validate(exercise)


@router.delete("/exercises/{exercise_id}/video", response_model=ExerciseOut)
async def admin_delete_exercise_video(
    exercise_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseOut:
    """Gỡ video hướng dẫn khỏi bài tập — quay về dùng video mẫu mặc định
    trong app (nếu có) hoặc không có video."""
    exercise = await exercise_crud.get_exercise_by_id(db, exercise_id)
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy bài tập.")

    old_url = exercise.demo_video_url
    exercise.demo_video_url = None
    await db.flush()
    exercise_video_service.delete_by_url(old_url)

    return ExerciseOut.model_validate(exercise)
