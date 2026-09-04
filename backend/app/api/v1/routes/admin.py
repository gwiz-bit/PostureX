"""Admin endpoints — chỉ user có is_admin=True mới truy cập được."""


from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import admin as admin_crud
from app.crud import exercise as exercise_crud
from app.crud import posture_rule as posture_rule_crud
from app.crud import subscription as sub_crud
from app.crud.notification import broadcast_notification, list_broadcast_history
from app.crud.user import get_user_by_id
from app.ml.analyzers.tunables import tunables_for
from app.ml.analyzers.tunables import validate as validate_tunables
from app.models.exercise import Exercise
from app.models.user import User
from app.schemas.admin import (
    AdminPaymentOut,
    AdminPlanCreate,
    AdminPlanOut,
    AdminPlanUpdate,
    AdminUserOut,
    AdminUserUpdate,
    BroadcastHistoryItem,
    BroadcastIn,
    BroadcastOut,
    ExerciseRulesOut,
    ExerciseRulesUpdate,
    RevenueByPlan,
    RevenueStats,
    SystemStats,
    TunableExerciseOut,
    TunableOut,
)
from app.schemas.exercise import ExerciseCreate, ExerciseOut, ExerciseUpdate
from app.services.exercise_video_service import exercise_video_service
from app.services.video_service import video_service
from app.utils.deps import get_current_admin

router = APIRouter(prefix="/admin", tags=["admin"])


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
# Ngưỡng phân tích tư thế theo từng bài tập
# ─────────────────────────────────────────────
#
# Thay cho cặp route `/config` cũ. Bản cũ giữ ngưỡng trong một biến module
# rồi gán đè lên hằng số toàn cục của `app.ml.analyzers.squat`, nên:
#
#   - Admin chỉnh xong, restart server là mất sạch — không cảnh báo gì.
#   - Sửa hằng số module tức là sửa MẶC ĐỊNH của SquatAnalyzer, mà mặc định đó
#     dùng chung cho cả 21 biến thể squat. Chỉnh cho "Barbell Squat" thì
#     "Machine Hack Squat" cũng đổi theo.
#   - Chỉ squat chỉnh được; 8 analyzer còn lại không có đường vào.
#
# Bản này ghi thẳng vào `ExercisePostureRules`, đúng bảng mà
# `_load_exercise_thresholds` đọc lúc mở phiên WebSocket — nên thay đổi sống
# qua restart và chỉ áp cho đúng bài được chỉnh.


async def _get_exercise_or_404(db: AsyncSession, exercise_id: int) -> Exercise:
    exercise = (
        await db.execute(select(Exercise).where(Exercise.id == exercise_id))
    ).scalar_one_or_none()
    if exercise is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy bài tập."
        )
    return exercise


def _build_rules_out(exercise: Exercise, analyzer: str, overrides: dict[str, float]) -> ExerciseRulesOut:
    return ExerciseRulesOut(
        exercise_id=exercise.id,
        exercise_name=exercise.name,
        analyzer=analyzer,
        tunables=[
            TunableOut(
                key=t.key,
                label=t.label,
                default=t.default,
                current=overrides.get(t.key),
                minimum=t.minimum,
                maximum=t.maximum,
                affects_rep_count=t.affects_rep_count,
                unit=t.unit,
                step=t.step,
            )
            for t in tunables_for(analyzer)
        ],
    )


@router.get("/posture-rules", response_model=list[TunableExerciseOut])
async def list_posture_rule_exercises(
    search: str | None = Query(None, description="Lọc theo tên bài tập."),
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[TunableExerciseOut]:
    """Các bài tập có analyzer, kèm số ngưỡng đang được ghi đè.

    Chỉ liệt kê bài phân tích được — bài không có analyzer thì không có ngưỡng
    nào để chỉnh.
    """
    rows = await posture_rule_crud.list_tunable_exercises(db, search)
    return [
        TunableExerciseOut(
            id=exercise.id, name=exercise.name, analyzer=analyzer, override_count=count
        )
        for exercise, analyzer, count in rows
    ]


@router.get("/posture-rules/{exercise_id}", response_model=ExerciseRulesOut)
async def get_posture_rules(
    exercise_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseRulesOut:
    """Ngưỡng chỉnh được của một bài, kèm mặc định và giá trị đang ghi đè."""
    exercise = await _get_exercise_or_404(db, exercise_id)
    analyzer = posture_rule_crud.analyzer_name_for(exercise.name)
    if analyzer is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bài '{exercise.name}' chưa có analyzer nên không có ngưỡng để chỉnh.",
        )
    overrides = await posture_rule_crud.get_overrides(db, exercise_id)
    return _build_rules_out(exercise, analyzer, overrides)


@router.put("/posture-rules/{exercise_id}", response_model=ExerciseRulesOut)
async def update_posture_rules(
    exercise_id: int,
    data: ExerciseRulesUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> ExerciseRulesOut:
    """Đặt lại ngưỡng ghi đè của một bài tập.

    `values` là trạng thái đầy đủ mong muốn: khoá bị bỏ ra sẽ được xoá và bài
    quay về mặc định của analyzer.

    Giá trị được kiểm trước khi ghi. Kiểm tra quan trọng nhất là thứ tự cặp
    ngưỡng đếm rep: nếu ngưỡng "đứng thẳng lại" không cao hơn ngưỡng "chạm
    đáy" một khoảng đủ rộng thì `RepCounter` đứng im ở 0 rep mà không báo lỗi
    gì — người dùng chỉ thấy "app không đếm được".
    """
    exercise = await _get_exercise_or_404(db, exercise_id)
    analyzer = posture_rule_crud.analyzer_name_for(exercise.name)
    if analyzer is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Bài '{exercise.name}' chưa có analyzer nên không có ngưỡng để chỉnh.",
        )

    errors = validate_tunables(analyzer, data.values)
    if errors:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=" ".join(errors)
        )

    overrides = await posture_rule_crud.replace_overrides(db, exercise_id, data.values)
    return _build_rules_out(exercise, analyzer, overrides)


# ─────────────────────────────────────────────
# Quản lý gói cước (SubscriptionPlans — hệ MoMo của hiepga)
# ─────────────────────────────────────────────
#
# LƯU Ý MERGE (hiepga): các endpoint admin quản lý gói/doanh thu/broadcast bản
# CŨ (dựa trên app.models.plan/transaction + admin_notifications) đã bị gỡ khi
# gộp nhánh hiepga vì không còn tương thích với hệ subscription mới (models/
# subscription.py: SubscriptionPlans/UserSubscriptions/Payments + MoMo). Các
# route dưới đây build lại đúng 3 chức năng đó nhưng trỏ thẳng vào bảng THẬT mà
# người dùng đang dùng để mua gói — không đụng tới app.models.plan/promo_code/
# transaction (đã orphan, giữ nguyên không xóa theo quyết định trước).

@router.get("/plans", response_model=list[AdminPlanOut])
async def admin_list_plans(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[AdminPlanOut]:
    """Toàn bộ gói cước, kể cả đã tắt bán."""
    plans = await sub_crud.list_all_plans(db)
    return [AdminPlanOut.model_validate(p) for p in plans]


@router.post("/plans", response_model=AdminPlanOut, status_code=status.HTTP_201_CREATED)
async def admin_create_plan(
    data: AdminPlanCreate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> AdminPlanOut:
    """Tạo gói cước mới."""
    plan = await sub_crud.create_plan(
        db,
        name=data.name,
        price_monthly=data.price_monthly,
        currency=data.currency,
        features=data.features,
        is_active=data.is_active,
    )
    return AdminPlanOut.model_validate(plan)


@router.patch("/plans/{plan_id}", response_model=AdminPlanOut)
async def admin_update_plan(
    plan_id: int,
    data: AdminPlanUpdate,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> AdminPlanOut:
    """Sửa gói cước (giá, tên, mô tả) hoặc tắt/bật bán.

    Không có DELETE thật — gói đã có người mua thì `UserSubscriptions`/`Payments`
    còn tham chiếu tới nó, xóa cứng sẽ vỡ lịch sử giao dịch. Tắt bán (`is_active
    = false`) là cách an toàn để "gỡ" một gói khỏi màn chọn gói của user.
    """
    plan = await sub_crud.get_plan_by_id(db, plan_id)
    if plan is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy gói cước.")
    updated = await sub_crud.update_plan(db, plan, **data.model_dump(exclude_unset=True))
    return AdminPlanOut.model_validate(updated)


# ─────────────────────────────────────────────
# Doanh thu (Payments)
# ─────────────────────────────────────────────

@router.get("/revenue", response_model=RevenueStats)
async def admin_get_revenue(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> RevenueStats:
    """Tổng doanh thu, breakdown theo gói, và các giao dịch gần nhất.

    Chỉ tính đơn `Payments.Status = 'Completed'` — đơn Pending/Failed không phải
    tiền thật đã thu.
    """
    total_revenue, total_count, by_plan_rows, recent_rows = await sub_crud.get_revenue_stats(db)
    return RevenueStats(
        total_revenue=total_revenue,
        total_paid_payments=total_count,
        by_plan=[
            RevenueByPlan(plan_id=r[0], plan_name=r[1], revenue=r[2], payment_count=r[3])
            for r in by_plan_rows
        ],
        recent_payments=[
            AdminPaymentOut(
                id=r[0],
                user_id=r[1],
                user_email=r[2],
                plan_name=r[3],
                amount=r[4],
                currency=r[5],
                status=r[6],
                paid_at=r[7],
                created_at=r[8],
            )
            for r in recent_rows
        ],
    )


# ─────────────────────────────────────────────
# Thông báo hàng loạt (broadcast)
# ─────────────────────────────────────────────

@router.get("/notifications/broadcast", response_model=list[BroadcastHistoryItem])
async def admin_broadcast_history(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> list[BroadcastHistoryItem]:
    """Lịch sử các lần gửi thông báo hàng loạt, mới nhất trước."""
    rows = await list_broadcast_history(db)
    return [
        BroadcastHistoryItem(title=r[0], body=r[1], created_at=r[2], recipients=r[3])
        for r in rows
    ]


@router.post("/notifications/broadcast", response_model=BroadcastOut)
async def admin_send_broadcast(
    data: BroadcastIn,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_admin),
) -> BroadcastOut:
    """Gửi thông báo cho toàn bộ user đang active (tài khoản bị khoá thì bỏ qua)."""
    result = await db.execute(select(User.id).where(User.is_active.is_(True)))
    user_ids = list(result.scalars().all())
    recipients = await broadcast_notification(db, user_ids, data.title, data.body)
    return BroadcastOut(recipients=recipients)


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
