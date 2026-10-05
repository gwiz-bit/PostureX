"""Model bảng coach_reports — người dùng báo cáo một câu trả lời của AI Coach.

Chính sách AI-Generated Content của Google Play yêu cầu app có chatbot AI phải
có cách để người dùng báo cáo nội dung không phù hợp ngay trong app. Bảng này
lưu ảnh chụp (snapshot) nội dung bị báo cáo thay vì khoá ngoại tới
`coach_messages`: người dùng có thể xoá lịch sử chat ngay sau khi báo cáo, mà
báo cáo thì vẫn phải còn nội dung để xem xét. Xoá theo user khi xoá tài khoản.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

REPORT_REASONS = ("inappropriate", "inaccurate", "unsafe", "other")


class CoachReport(Base):
    __tablename__ = "coach_reports"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    reason: Mapped[str] = mapped_column(String(20), nullable=False)
    message_content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
