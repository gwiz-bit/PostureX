"""Pydantic schemas cho AI Coach chat (tư vấn tập luyện/dinh dưỡng)."""

from datetime import datetime

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    """Một lượt hội thoại — role 'user' (người dùng) hoặc 'model' (AI). Dùng
    nội bộ để dựng ngữ cảnh gửi Gemini (xem `ai_coach_service._to_contents`),
    KHÔNG phải hình dạng API — client không còn gửi lịch sử lên nữa, xem
    `CoachChatRequest`."""
    role: str = Field(pattern="^(user|model)$")
    content: str


class CoachChatRequest(BaseModel):
    """Từ 11/09/2026: KHÔNG còn trường `history`. Server tự đọc lịch sử gần
    nhất từ bảng `coach_messages` (xem `crud/coach_message.py`) thay vì tin
    vào client gửi kèm — sửa đúng lỗ hổng "rời màn chat là mất lịch sử" vì
    trước đó lịch sử chỉ tồn tại trong RAM phía Flutter."""
    message: str = Field(min_length=1, max_length=2000)


class CoachChatResponse(BaseModel):
    reply: str


class CoachMessageOut(BaseModel):
    """Một tin nhắn đã lưu, trả về cho `GET /coach/history`."""
    model_config = {"from_attributes": True}

    role: str
    content: str
    created_at: datetime


class PlanExerciseOut(BaseModel):
    name: str
    sets_reps: str


class PlanDayOut(BaseModel):
    day_label: str = Field(pattern="^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$")
    session_name: str
    is_rest: bool
    exercises: list[PlanExerciseOut]
    # Gợi ý dinh dưỡng ngắn cho ngày đó — kể cả ngày nghỉ (ăn gì để phục hồi).
    nutrition_tip: str


class AiPlanResponse(BaseModel):
    """Lịch tập + dinh dưỡng 7 ngày (Mon..Sun) do Gemini soạn riêng cho user,
    dựa trên hồ sơ thể chất + lịch sử tập thật — thay cho lịch mẫu cố định
    sinh ở client lúc onboarding."""
    days: list[PlanDayOut] = Field(min_length=7, max_length=7)
