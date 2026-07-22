"""Endpoint chat với AI Coach — tư vấn tập luyện/dinh dưỡng cá nhân hóa."""

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.crud.profile import get_profile
from app.models.user import User
from app.models.workout import Workout
from app.schemas.coach import CoachChatRequest, CoachChatResponse
from app.services import ai_coach_service
from app.utils.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/coach", tags=["coach"])


async def _build_user_context(db: AsyncSession, user: User) -> str:
    """Tóm tắt hồ sơ + lịch sử tập của user thành đoạn text đưa vào system
    prompt — để lời khuyên của AI thực sự cá nhân hóa thay vì chung chung."""
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
    if profile.fitness_level:
        lines.append(f"Mức độ tập luyện: {profile.fitness_level}")
    if profile.weekly_goal:
        lines.append(f"Mục tiêu: {profile.weekly_goal} buổi/tuần")

    session_count = (
        await db.execute(select(func.count()).select_from(Workout).where(Workout.user_id == user.id))
    ).scalar_one()
    if session_count:
        avg_accuracy = (
            await db.execute(
                select(func.avg(Workout.accuracy_score)).where(
                    Workout.user_id == user.id, Workout.accuracy_score.is_not(None)
                )
            )
        ).scalar_one()
        lines.append(f"Đã tập {session_count} buổi")
        if avg_accuracy is not None:
            lines.append(f"Độ chính xác tư thế trung bình: {avg_accuracy:.0f}%")

        recent = (
            await db.execute(
                select(Workout.exercise, Workout.total_reps)
                .where(Workout.user_id == user.id)
                .order_by(Workout.started_at.desc())
                .limit(5)
            )
        ).all()
        if recent:
            recent_text = ", ".join(f"{ex} ({reps} reps)" for ex, reps in recent)
            lines.append(f"5 buổi tập gần nhất: {recent_text}")
    else:
        lines.append("Chưa có buổi tập nào được ghi nhận.")

    return "\n".join(lines)


@router.post("/chat", response_model=CoachChatResponse)
async def chat(
    data: CoachChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CoachChatResponse:
    """Gửi 1 câu hỏi tới AI Coach, kèm ngữ cảnh hồ sơ + lịch sử tập thật của
    user hiện tại để lời khuyên cá nhân hóa."""
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
