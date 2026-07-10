"""Model bảng Users — ánh xạ vào schema PostureX MySQL (sql/postureX123_schema.sql).

Bảng này được tạo bởi script schema, không phải bởi create_tables.py — chỉ
videos/workouts vẫn do SQLAlchemy quản lý (xem create_tables.py).
"""

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, DateTime, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.role import ADMIN_ROLE_NAME, Role

if TYPE_CHECKING:
    from app.models.video import Video
    from app.models.workout import Workout


class User(Base):
    __tablename__ = "Users"

    id: Mapped[int] = mapped_column("UserId", primary_key=True)
    role_id: Mapped[int] = mapped_column("RoleId", ForeignKey("Roles.RoleId"), nullable=False)
    username: Mapped[str] = mapped_column("Username", String(50), unique=True, nullable=False)
    email: Mapped[str] = mapped_column("Email", String(256), unique=True, index=True, nullable=False)
    phone_number: Mapped[str | None] = mapped_column("PhoneNumber", String(20), nullable=True)
    hashed_password: Mapped[str] = mapped_column("PasswordHash", String(255), nullable=False)
    full_name: Mapped[str | None] = mapped_column("FullName", String(100), nullable=True)
    is_email_verified: Mapped[bool] = mapped_column("IsEmailVerified", Boolean, default=False)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        "RegisteredAt", DateTime, default=lambda: datetime.now(timezone.utc)
    )
    last_login_at: Mapped[datetime | None] = mapped_column("LastLoginAt", DateTime, nullable=True)

    # selectin: nạp sẵn cùng lúc với User để tránh lazy-load bất đồng bộ khi
    # đọc is_admin (property đồng bộ, không await được nếu role chưa nạp).
    role: Mapped["Role"] = relationship("Role", lazy="selectin")

    videos: Mapped[list["Video"]] = relationship("Video", back_populates="user")
    workouts: Mapped[list["Workout"]] = relationship("Workout", back_populates="user")

    @property
    def is_admin(self) -> bool:
        """True nếu vai trò của user là Admin. Suy ra từ RoleId/Roles thay
        vì một cột boolean riêng — khớp với schema PostureX MySQL."""
        return self.role is not None and self.role.name == ADMIN_ROLE_NAME
