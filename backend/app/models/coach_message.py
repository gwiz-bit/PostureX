"""Model bảng coach_messages — lưu lịch sử hội thoại AI Coach theo từng user.

Trước 11/09/2026, lịch sử chat chỉ tồn tại trong RAM phía Flutter
(`AiCoachController.messages`) — rời màn AI Coach là mất sạch, server không
lưu gì cả (`POST /coach/chat` nhận `history` do CLIENT tự gửi kèm mỗi lần).
Bảng này đổi server thành nguồn sự thật duy nhất: mỗi lượt hỏi/đáp được ghi
lại 2 dòng (`role='user'` và `role='model'`), và `POST /coach/chat` tự đọc
N tin nhắn gần nhất từ đây làm ngữ cảnh thay vì tin vào client.

Một cuộc hội thoại LIÊN TỤC cho mỗi user, không có khái niệm nhiều "phiên"
riêng biệt — khớp đúng với cách UI hiện tại hoạt động (một màn chat, không
có danh sách hội thoại)."""

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

if TYPE_CHECKING:
    from app.models.user import User


class CoachMessage(Base):
    __tablename__ = "coach_messages"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("Users.UserId"), nullable=False, index=True)
    # 'user' hoặc 'model' — khớp thẳng vocabulary role của Gemini, không dịch
    # qua lại (xem ChatMessage trong schemas/coach.py).
    role: Mapped[str] = mapped_column(String(10), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )

    user: Mapped["User"] = relationship("User")
