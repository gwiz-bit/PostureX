"""Pydantic schemas cho AI Coach chat (tư vấn tập luyện/dinh dưỡng)."""

from pydantic import BaseModel, Field


class ChatMessage(BaseModel):
    """Một lượt hội thoại — role 'user' (người dùng) hoặc 'model' (AI)."""
    role: str = Field(pattern="^(user|model)$")
    content: str


class CoachChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    # Lịch sử hội thoại do client tự giữ và gửi lại mỗi lần (server không
    # lưu trữ hội thoại) — giới hạn 20 lượt gần nhất để tránh prompt phình
    # to vô hạn.
    history: list[ChatMessage] = Field(default_factory=list, max_length=20)


class CoachChatResponse(BaseModel):
    reply: str


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
