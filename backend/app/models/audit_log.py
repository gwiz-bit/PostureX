"""Model bảng AuditLogs (schema PostureX)."""

from datetime import datetime, timezone

from sqlalchemy import BigInteger, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AuditLog(Base):
    """Nhật ký thao tác — khớp đúng bảng AuditLogs trong sql/postureX123_schema.sql
    (và DB production thật). Không thêm cột nào ngoài schema gốc ở đây — DB
    production không được migrate theo model, nên model phải khớp DB, không
    phải ngược lại."""

    __tablename__ = "AuditLogs"

    id: Mapped[int] = mapped_column("AuditLogId", BigInteger, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column("Action", String(100), nullable=False)
    entity_name: Mapped[str | None] = mapped_column("EntityName", String(100), nullable=True)
    entity_id: Mapped[str | None] = mapped_column("EntityId", String(50), nullable=True)
    details: Mapped[str | None] = mapped_column("Details", String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True
    )
