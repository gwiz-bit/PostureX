"""Model bảng UserSettings (schema PostureX)."""

from sqlalchemy import ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserSettings(Base):
    """Thiết lập cá nhân của từng user — one-to-one với Users."""

    __tablename__ = "UserSettings"

    id: Mapped[int] = mapped_column("SettingId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, unique=True
    )
    language: Mapped[str] = mapped_column("Language", String(10), nullable=False, default="vi")
    theme: Mapped[str] = mapped_column("Theme", String(20), nullable=False, default="dark")
    notification_enabled: Mapped[bool] = mapped_column(
        "NotificationEnabled", SmallInteger, nullable=False, default=1
    )
    workout_reminder_enabled: Mapped[bool] = mapped_column(
        "WorkoutReminderEnabled", SmallInteger, nullable=False, default=1
    )
    workout_reminder_time: Mapped[str | None] = mapped_column(
        "WorkoutReminderTime", String(5), nullable=True
    )  # HH:MM
    voice_feedback_enabled: Mapped[bool] = mapped_column(
        "VoiceFeedbackEnabled", SmallInteger, nullable=False, default=1
    )
    skeleton_overlay_enabled: Mapped[bool] = mapped_column(
        "SkeletonOverlayEnabled", SmallInteger, nullable=False, default=1
    )
    data_sharing_consent: Mapped[bool] = mapped_column(
        "DataSharingConsent", SmallInteger, nullable=False, default=0
    )
