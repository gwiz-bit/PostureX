"""Model bảng PostureErrorTypes (schema PostureX).

Danh mục lỗi kỹ thuật — hiện chưa có endpoint/route nào đọc bảng này
(câu nhắc giọng nói tiếng Việt trong đó chưa được tích hợp). Model chỉ tồn
tại để ensure_tables.py tạo bảng đúng schema, và để RealtimeFeedback có thể
tham chiếu ErrorTypeId về sau.
"""

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class PostureErrorType(Base):
    """Loại lỗi kỹ thuật chuẩn — ví dụ KNEE_VALGUS, BACK_ROUND."""

    __tablename__ = "PostureErrorTypes"

    id: Mapped[int] = mapped_column("ErrorTypeId", primary_key=True)
    exercise_id: Mapped[int | None] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId"), nullable=True
    )  # NULL = lỗi áp dụng chung cho mọi bài
    error_code: Mapped[str] = mapped_column("ErrorCode", String(50), nullable=False, unique=True)
    error_name: Mapped[str] = mapped_column("ErrorName", String(150), nullable=False)
    severity: Mapped[str] = mapped_column("Severity", String(20), nullable=False, default="Medium")
    correction_tip: Mapped[str | None] = mapped_column("CorrectionTip", String(500), nullable=True)
    voice_prompt: Mapped[str | None] = mapped_column("VoicePrompt", String(255), nullable=True)
