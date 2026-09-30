"""Models bảng AiQaPairs và AiSafetyRules — nội dung cho AI Coach.

AiQaPairs: cặp hỏi-đáp seed sẵn (có thể dùng cho RAG sau này).
AiSafetyRules: luật an toàn AI phải tuân thủ tuyệt đối.
"""

from sqlalchemy import SmallInteger, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AiQaPair(Base):
    """Cặp hỏi-đáp seed sẵn, dùng làm ngữ cảnh hoặc RAG cho AI Coach."""

    __tablename__ = "AiQaPairs"

    id: Mapped[int] = mapped_column("QaId", primary_key=True)
    category: Mapped[str] = mapped_column("Category", String(40), nullable=False)
    question: Mapped[str] = mapped_column("Question", String(500), nullable=False)
    answer: Mapped[str] = mapped_column("Answer", Text, nullable=False)
    source_table: Mapped[str | None] = mapped_column("SourceTable", String(50), nullable=True)


class AiSafetyRule(Base):
    """Luật an toàn AI — IsBlocking=1 nghĩa là chặn cứng."""

    __tablename__ = "AiSafetyRules"

    id: Mapped[int] = mapped_column("SafetyRuleId", primary_key=True)
    rule_type: Mapped[str] = mapped_column("RuleType", String(40), nullable=False)
    situation: Mapped[str] = mapped_column("Situation", Text, nullable=False)
    required_behaviour: Mapped[str] = mapped_column("RequiredBehaviour", Text, nullable=False)
    is_blocking: Mapped[int] = mapped_column("IsBlocking", SmallInteger, nullable=False, default=1)
