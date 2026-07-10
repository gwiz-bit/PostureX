"""Model bảng Roles (Admin/User) — bảng được quản lý bởi sql/postureX123_schema.sql,
SQLAlchemy chỉ ánh xạ để đọc, không tự tạo/xóa bảng này."""

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base

ADMIN_ROLE_NAME = "Admin"
USER_ROLE_NAME = "User"


class Role(Base):
    __tablename__ = "Roles"

    id: Mapped[int] = mapped_column("RoleId", primary_key=True)
    name: Mapped[str] = mapped_column("RoleName", String(50), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column("Description", String(255), nullable=True)
