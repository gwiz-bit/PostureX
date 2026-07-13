"""Model bảng Exercises — thư viện bài tập, đã có sẵn trong schema PostureX
gốc (sql/postureX123_schema.sql) nhưng chưa được backend nào dùng tới.
Bảng này do schema quản lý (như Users/Roles) — không tạo/drop qua
create_tables.py."""

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Exercise(Base):
    __tablename__ = "Exercises"

    id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)
    name: Mapped[str] = mapped_column("Name", String(100), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column("Description", String(1000), nullable=True)
    category: Mapped[str | None] = mapped_column("Category", String(50), nullable=True)
    difficulty: Mapped[str | None] = mapped_column("Difficulty", String(20), nullable=True)
    exercise_type: Mapped[str] = mapped_column("ExerciseType", String(20), default="Standard")
    demo_video_url: Mapped[str | None] = mapped_column("DemoVideoUrl", String(500), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column("ThumbnailUrl", String(500), nullable=True)
    met: Mapped[float | None] = mapped_column("Met", Numeric(4, 2), nullable=True)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, default=lambda: datetime.now(timezone.utc)
    )
