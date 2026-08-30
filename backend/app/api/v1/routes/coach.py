"""Endpoint chat với AI Coach — tư vấn tập luyện/dinh dưỡng cá nhân hóa."""

import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.crud.exercise import get_active_exercises, get_muscle_groups_by_exercise
from app.crud.profile import get_profile
from app.ml.analyzers.registry import supports_analysis
from app.models.user import User
from app.models.workout import Workout
from app.schemas.coach import AiPlanResponse, CoachChatRequest, CoachChatResponse
from app.services import ai_coach_service
from app.utils.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/coach", tags=["coach"])

# Số bài tập tối đa gửi kèm prompt cho MỖI nhóm cơ.
#
# Trước đây gửi thẳng cả thư viện. Hồi đó chỉ có 6 bài nên không sao, nhưng
# sau khi nhập thư viện thật thì thành 417 tên ≈ 9.400 ký tự ≈ 2.400 token
# input cho MỖI lần bấm "Personalize with AI" — vừa tốn quota, vừa làm giảm
# chất lượng vì bắt model chọn giữa 417 cái tên na ná nhau.
#
# Cắt theo từng nhóm cơ thay vì cắt thẳng danh sách: cắt thẳng thì các nhóm
# đứng cuối bảng chữ cái biến mất hoàn toàn và lịch tập ra sẽ lệch. 8 bài/nhóm
# đủ để model có lựa chọn mà tổng vẫn chỉ khoảng một phần tư số token cũ.
_MAX_EXERCISES_PER_MUSCLE_GROUP = 8


async def _build_exercise_catalogue(db: AsyncSession) -> str:
    """Danh mục bài tập gửi kèm prompt sinh lịch, gom theo nhóm cơ.

    Gom theo nhóm cơ chứ không phải một danh sách phẳng, vì bản thân prompt
    yêu cầu "phân bổ nhóm cơ hợp lý trong tuần" — cho sẵn cấu trúc đó thì
    model không phải tự đoán bài nào thuộc nhóm nào.

    Bài có analyzer tư thế được đánh dấu `*` và xếp lên đầu mỗi nhóm. Đó là
    giá trị cốt lõi của app: lịch tập gồm toàn bài mà app chấm được kỹ thuật
    thì hữu ích hơn hẳn lịch gồm bài chỉ xem được video. Nhưng KHÔNG lọc bỏ
    hẳn bài không có analyzer — 106 bài có analyzer chỉ phủ 9/16 nhóm cơ,
    riêng Biceps, Calves, Forearms, Lower Back, Adductors, Neck, tibialis
    không có bài nào, nên lọc cứng sẽ khiến model không dựng nổi tuần cân bằng.
    """
    exercises = await get_active_exercises(db)
    if not exercises:
        return "(chưa có dữ liệu)"

    groups = await get_muscle_groups_by_exercise(db, [e.id for e in exercises])

    by_group: dict[str, list[tuple[bool, str]]] = defaultdict(list)
    for e in exercises:
        analyzable = supports_analysis(e.name)
        # Bài chưa gán nhóm cơ vẫn phải xuất hiện, nếu không sẽ âm thầm biến
        # mất khỏi mọi lịch tập AI sinh ra.
        for group in groups.get(e.id) or ["Khác"]:
            by_group[group].append((analyzable, e.name))

    lines: list[str] = []
    for group in sorted(by_group):
        # `not analyzable` để False (có analyzer) xếp trước, rồi mới theo tên.
        picked = sorted(by_group[group], key=lambda item: (not item[0], item[1]))
        names = [
            f"*{name}" if analyzable else name
            for analyzable, name in picked[:_MAX_EXERCISES_PER_MUSCLE_GROUP]
        ]
        lines.append(f"- {group}: {', '.join(names)}")
    return "\n".join(lines)


async def _build_user_context(db: AsyncSession, user: User) -> str:
    """Tóm tắt hồ sơ + lịch sử tập của user thành đoạn text đưa vào system
    prompt — để lời khuyên của AI thực sự cá nhân hóa và có số liệu cụ thể
    để phân tích, thay vì chỉ liệt kê thông tin chung chung."""
    lines = [f"Tên: {user.full_name or 'Chưa cập nhật'}"]

    profile = await get_profile(db, user.id)
    if profile.age:
        lines.append(f"Tuổi: {profile.age}")
    if profile.gender:
        lines.append(f"Giới tính: {profile.gender}")
    if profile.height_cm:
        lines.append(f"Chiều cao: {profile.height_cm} cm")
    if profile.weight_kg:
        lines.append(f"Cân nặng: {profile.weight_kg} kg")
    if profile.height_cm and profile.weight_kg:
        bmi = profile.weight_kg / ((profile.height_cm / 100) ** 2)
        lines.append(f"BMI: {bmi:.1f}")
    if profile.fitness_level:
        lines.append(f"Mức độ tập luyện: {profile.fitness_level}")
    if profile.weekly_goal:
        lines.append(f"Mục tiêu: {profile.weekly_goal} buổi/tuần")

    session_count = (
        await db.execute(select(func.count()).select_from(Workout).where(Workout.user_id == user.id))
    ).scalar_one()
    if not session_count:
        lines.append("Chưa có buổi tập nào được ghi nhận.")
        return "\n".join(lines)

    avg_accuracy = (
        await db.execute(
            select(func.avg(Workout.accuracy_score)).where(
                Workout.user_id == user.id, Workout.accuracy_score.is_not(None)
            )
        )
    ).scalar_one()
    lines.append(f"Tổng số buổi đã tập: {session_count}")
    if avg_accuracy is not None:
        lines.append(f"Độ chính xác tư thế trung bình (toàn thời gian): {avg_accuracy:.0f}%")

    last_workout_at = (
        await db.execute(
            select(func.max(Workout.started_at)).where(Workout.user_id == user.id)
        )
    ).scalar_one()
    if last_workout_at is not None:
        days_since = (datetime.now(timezone.utc) - last_workout_at.replace(tzinfo=timezone.utc)).days
        lines.append(f"Buổi tập gần nhất: {days_since} ngày trước")

    since_7d = datetime.now(timezone.utc) - timedelta(days=7)
    sessions_this_week = (
        await db.execute(
            select(func.count())
            .select_from(Workout)
            .where(Workout.user_id == user.id, Workout.started_at >= since_7d)
        )
    ).scalar_one()
    if profile.weekly_goal:
        lines.append(
            f"Đã tập {sessions_this_week}/{profile.weekly_goal} buổi trong 7 ngày qua "
            f"({'đạt' if sessions_this_week >= profile.weekly_goal else 'CHƯA đạt'} mục tiêu tuần)"
        )
    else:
        lines.append(f"Đã tập {sessions_this_week} buổi trong 7 ngày qua")

    # Breakdown theo từng bài — sắp xếp từ độ chính xác thấp nhất lên, để AI
    # dễ nhận ra ngay bài nào đang yếu nhất mà chủ động góp ý kỹ thuật.
    by_exercise = (
        await db.execute(
            select(
                Workout.exercise,
                func.count().label("cnt"),
                func.avg(Workout.accuracy_score).label("avg_acc"),
                func.sum(Workout.total_reps).label("total_reps"),
            )
            .where(Workout.user_id == user.id)
            .group_by(Workout.exercise)
            .order_by(func.avg(Workout.accuracy_score).asc())
        )
    ).all()
    if by_exercise:
        lines.append("Chi tiết theo từng bài tập (sắp theo độ chính xác tăng dần):")
        for exercise, cnt, avg_acc, total_reps in by_exercise:
            acc_text = f"{avg_acc:.0f}% chính xác TB" if avg_acc is not None else "chưa có điểm chính xác"
            lines.append(f"  - {exercise}: {cnt} buổi, {int(total_reps or 0)} reps, {acc_text}")

    # Xu hướng gần đây: so 5 buổi mới nhất với phần còn lại để biết đang cải
    # thiện hay tụt lùi — số liệu này quan trọng hơn nhiều so với chỉ liệt kê
    # 5 buổi gần nhất suông.
    recent = (
        await db.execute(
            select(Workout.exercise, Workout.total_reps, Workout.accuracy_score)
            .where(Workout.user_id == user.id)
            .order_by(Workout.started_at.desc())
            .limit(5)
        )
    ).all()
    if recent:
        recent_text = ", ".join(
            f"{ex} ({reps} reps"
            + (f", {acc:.0f}%" if acc is not None else "")
            + ")"
            for ex, reps, acc in recent
        )
        lines.append(f"5 buổi tập gần nhất: {recent_text}")

        recent_accs = [acc for _, _, acc in recent if acc is not None]
        if recent_accs and avg_accuracy is not None:
            recent_avg = sum(recent_accs) / len(recent_accs)
            delta = recent_avg - avg_accuracy
            if abs(delta) >= 3:
                trend = "đang CẢI THIỆN" if delta > 0 else "đang GIẢM SÚT"
                lines.append(
                    f"Xu hướng độ chính xác: {trend} ({recent_avg:.0f}% gần đây so với "
                    f"{avg_accuracy:.0f}% trung bình toàn thời gian)"
                )
            else:
                lines.append("Xu hướng độ chính xác: ổn định, không thay đổi rõ rệt gần đây")

    return "\n".join(lines)


@router.post("/chat", response_model=CoachChatResponse)
@limiter.limit("10/minute;100/hour")
async def chat(
    request: Request,
    data: CoachChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CoachChatResponse:
    """Gửi 1 câu hỏi tới AI Coach, kèm ngữ cảnh hồ sơ + lịch sử tập thật của
    user hiện tại để lời khuyên cá nhân hóa.

    Có rate limit vì đây là endpoint tiêu tiền thật: mỗi request là một lượt
    gọi Gemini, tính vào quota của khoá API trong .env. Không giới hạn thì
    một tài khoản chạy vòng lặp là đốt sạch hạn mức, và mọi người dùng khác
    mất luôn AI Coach. Đặt hai mức — 10/phút vẫn rộng rãi cho hội thoại của
    người thật (nhanh nhất cũng vài giây mới gõ xong một câu), 100/giờ chặn
    kiểu gọi đều đều né ngưỡng phút.

    `request: Request` là tham số slowapi bắt buộc phải có để lấy IP, không
    phải dư thừa — bỏ đi là decorator ném lỗi lúc khởi động.
    """
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI Coach chưa được cấu hình trên server.",
        )

    user_context = await _build_user_context(db, current_user)
    try:
        reply = await ai_coach_service.ask(
            message=data.message, history=data.history, user_context=user_context
        )
    except Exception as e:
        logger.warning("AI Coach request failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Không thể kết nối tới AI Coach lúc này. Thử lại sau.",
        )

    return CoachChatResponse(reply=reply)


@router.post("/plan", response_model=AiPlanResponse)
@limiter.limit("5/minute;20/hour")
async def generate_plan(
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AiPlanResponse:
    """Sinh lịch tập + dinh dưỡng 7 ngày (Mon..Sun) cá nhân hóa bằng AI, dựa
    trên hồ sơ thể chất + lịch sử tập thật — client dùng kết quả này để thay
    thế lịch tập mẫu cố định trên Home.

    Giới hạn chặt hơn /chat vì mỗi lượt sinh lịch tốn nhiều token hơn hẳn —
    prompt kèm toàn bộ danh sách bài tập trong DB, đầu ra là structured
    output cho cả 7 ngày — trong khi nhu cầu thật chỉ vài lần mỗi tuần.
    5/phút vẫn đủ để bấm lại ngay khi lịch chưa ưng ý, 20/giờ chặn lạm dụng.

    Xem chú thích ở `chat` về lý do bắt buộc có `request: Request`.
    """
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI Coach chưa được cấu hình trên server.",
        )

    user_context = await _build_user_context(db, current_user)
    exercise_catalogue = await _build_exercise_catalogue(db)
    try:
        return await ai_coach_service.generate_plan(
            user_context=user_context,
            exercise_catalogue=exercise_catalogue,
        )
    except Exception as e:
        logger.warning("AI plan generation failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Không thể tạo lịch tập lúc này. Thử lại sau.",
        )
