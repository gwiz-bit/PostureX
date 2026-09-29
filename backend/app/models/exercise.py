"""Model bảng Exercises — thư viện bài tập.

Thay đổi v2: thêm Slug, NameVi, MovementRoleId FK, EquipmentTier, Impact,
SpineLoad, SupportsAnalysis, ExcludedReason. Bảng có trigger
trg_Exercises_BeforeInsert tự sinh Slug và ghi ExcludedReason mặc định
khi ORM không truyền các cột đó.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Exercise(Base):
    __tablename__ = "Exercises"

    id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)
    # Slug tự sinh từ trigger nếu ORM không truyền — KHÔNG đặt NOT NULL ở Python
    # vì trigger lo phần đó trên MySQL; SQLite test fixture không có trigger.
    slug: Mapped[str | None] = mapped_column("Slug", String(80), nullable=True, unique=True)
    name: Mapped[str] = mapped_column("Name", String(100), unique=True, nullable=False)
    name_vi: Mapped[str | None] = mapped_column("NameVi", String(120), nullable=True)
    description: Mapped[str | None] = mapped_column("Description", String(1000), nullable=True)
    movement_role_id: Mapped[int | None] = mapped_column(
        "MovementRoleId", ForeignKey("MovementRoles.MovementRoleId"), nullable=True
    )
    category: Mapped[str | None] = mapped_column("Category", String(50), nullable=True)
    difficulty: Mapped[str | None] = mapped_column("Difficulty", String(20), nullable=True)
    exercise_type: Mapped[str] = mapped_column("ExerciseType", String(20), default="Standard")
    equipment_tier: Mapped[str] = mapped_column("EquipmentTier", String(2), nullable=False, default="T2")
    impact: Mapped[str | None] = mapped_column("Impact", String(10), nullable=True)
    spine_load: Mapped[str | None] = mapped_column("SpineLoad", String(10), nullable=True)
    supports_analysis: Mapped[int] = mapped_column(
        "SupportsAnalysis", SmallInteger, nullable=False, default=0
    )
    excluded_reason: Mapped[str | None] = mapped_column("ExcludedReason", String(255), nullable=True)
    demo_video_url: Mapped[str | None] = mapped_column("DemoVideoUrl", String(500), nullable=True)
    thumbnail_url: Mapped[str | None] = mapped_column("ThumbnailUrl", String(500), nullable=True)
    met: Mapped[float | None] = mapped_column("Met", Numeric(4, 2), nullable=True)
    is_active: Mapped[bool] = mapped_column("IsActive", Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        "CreatedAt", DateTime, default=lambda: datetime.now(timezone.utc)
    )
