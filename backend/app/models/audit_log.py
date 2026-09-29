"""Model bảng AuditLogs (schema PostureX)."""

from datetime import datetime, timezone

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AuditLog(Base):
    """Nhật ký thao tác — ghi lại mọi thay đổi quan trọng trong hệ thống."""

    __tablename__ = "AuditLogs"

    id: Mapped[int] = mapped_column("AuditLogId", BigInteger, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="SET NULL"), nullable=True, index=True
    )
    action: Mapped[str] = mapped_column("Action", String(100), nullable=False)
    table_name: Mapped[str | None] = mapped_column("TableName", String(64), nullable=True)
    record_id: Mapped[int | None] = mapped_column("RecordId", BigInteger, nullable=True)
    old_values: Mapped[str | None] = mapped_column("OldValues", Text, nullable=True)
    new_values: Mapped[str | None] = mapped_column("NewValues", Text, nullable=True)
    ip_address: Mapped[str | None] = mapped_column("IpAddress", String(45), nullable=True)
    user_agent: Mapped[str | None] = mapped_column("UserAgent", String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc), index=True
    )
