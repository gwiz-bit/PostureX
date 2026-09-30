"""Models bảng Achievements và UserAchievements (schema PostureX)."""

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, SmallInteger, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class Achievement(Base):
    """Danh mục thành tích — định nghĩa cứng (seed), không do user tạo."""

    __tablename__ = "Achievements"

    id: Mapped[int] = mapped_column("AchievementId", primary_key=True)
    achievement_key: Mapped[str] = mapped_column("AchievementKey", String(50), nullable=False, unique=True)
    name: Mapped[str] = mapped_column("AchievementName", String(150), nullable=False)
    description: Mapped[str | None] = mapped_column("Description", Text, nullable=True)
    badge_icon: Mapped[str | None] = mapped_column("BadgeIcon", String(100), nullable=True)
    criteria_type: Mapped[str | None] = mapped_column("CriteriaType", String(50), nullable=True)
    criteria_value: Mapped[int | None] = mapped_column("CriteriaValue", Integer, nullable=True)
    xp_reward: Mapped[int] = mapped_column("XpReward", Integer, nullable=False, default=0)
    is_active: Mapped[bool] = mapped_column("IsActive", SmallInteger, nullable=False, default=1)

    user_achievements: Mapped[list["UserAchievement"]] = relationship(
        "UserAchievement", back_populates="achievement"
    )


class UserAchievement(Base):
    """Thành tích một user đã mở khoá — ghi thời điểm mở."""

    __tablename__ = "UserAchievements"

    id: Mapped[int] = mapped_column("UserAchievementId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    achievement_id: Mapped[int] = mapped_column(
        "AchievementId", ForeignKey("Achievements.AchievementId"), nullable=False
    )
    earned_at: Mapped[datetime] = mapped_column(
        "EarnedAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    current_value: Mapped[int | None] = mapped_column("CurrentValue", Integer, nullable=True)
    is_notified: Mapped[bool] = mapped_column("IsNotified", SmallInteger, nullable=False, default=0)

    achievement: Mapped["Achievement"] = relationship("Achievement", back_populates="user_achievements")
