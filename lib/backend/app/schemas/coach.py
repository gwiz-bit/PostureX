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
