"""Model bảng BodyMeasurements (schema PostureX)."""

from datetime import date, datetime, timezone

from sqlalchemy import Date, DateTime, ForeignKey, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class BodyMeasurement(Base):
    """Một lần đo cơ thể của user — cân nặng, BF%, các số đo vòng."""

    __tablename__ = "BodyMeasurements"

    id: Mapped[int] = mapped_column("MeasurementId", primary_key=True)
    user_id: Mapped[int] = mapped_column(
        "UserId", ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    measured_at: Mapped[datetime] = mapped_column(
        "MeasuredAt", DateTime, nullable=False, default=lambda: datetime.now(timezone.utc)
    )
    measurement_date: Mapped[date | None] = mapped_column("MeasurementDate", Date, nullable=True)
    weight_kg: Mapped[float | None] = mapped_column("WeightKg", Numeric(6, 2), nullable=True)
    body_fat_pct: Mapped[float | None] = mapped_column("BodyFatPct", Numeric(5, 2), nullable=True)
    muscle_mass_kg: Mapped[float | None] = mapped_column("MuscleMassKg", Numeric(6, 2), nullable=True)
    bmi: Mapped[float | None] = mapped_column("Bmi", Numeric(5, 2), nullable=True)
    chest_cm: Mapped[float | None] = mapped_column("ChestCm", Numeric(5, 1), nullable=True)
    waist_cm: Mapped[float | None] = mapped_column("WaistCm", Numeric(5, 1), nullable=True)
    hips_cm: Mapped[float | None] = mapped_column("HipsCm", Numeric(5, 1), nullable=True)
    left_arm_cm: Mapped[float | None] = mapped_column("LeftArmCm", Numeric(5, 1), nullable=True)
    right_arm_cm: Mapped[float | None] = mapped_column("RightArmCm", Numeric(5, 1), nullable=True)
    left_thigh_cm: Mapped[float | None] = mapped_column("LeftThighCm", Numeric(5, 1), nullable=True)
    right_thigh_cm: Mapped[float | None] = mapped_column("RightThighCm", Numeric(5, 1), nullable=True)
