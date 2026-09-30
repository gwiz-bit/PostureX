"""Models bảng onboarding — 14 câu hỏi và lựa chọn.

Nhóm bảng này lưu TẬP HỢP LỰA CHỌN (seed sẵn bởi admin), không lưu câu trả lời
của user (xem user_onboarding.py cho phần đó).
"""

from __future__ import annotations

from decimal import Decimal

from sqlalchemy import Numeric, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class OnboardingGoal(Base):
    """Câu 1: 12 mục tiêu luyện tập (BuildMuscle, LoseFat, …)."""

    __tablename__ = "OnboardingGoals"

    code: Mapped[str] = mapped_column("GoalCode", String(30), primary_key=True)
    label: Mapped[str] = mapped_column("Label", String(60), nullable=False)


class GoalDirectionScore(Base):
    """Điểm ưu tiên: mỗi mục tiêu cộng bao nhiêu điểm cho mỗi hướng giáo án."""

    __tablename__ = "GoalDirectionScores"

    goal_code: Mapped[str] = mapped_column(
        "GoalCode", String(30), primary_key=True
    )
    direction: Mapped[str] = mapped_column("Direction", String(20), primary_key=True)
    score: Mapped[int] = mapped_column("Score", SmallInteger, nullable=False, default=0)


class EquipmentOption(Base):
    """Câu 12: dụng cụ hiện có (T0=không có gì, T1=tạ đơn, T2=phòng gym)."""

    __tablename__ = "EquipmentOptions"

    code: Mapped[str] = mapped_column("EquipmentCode", String(30), primary_key=True)
    label: Mapped[str] = mapped_column("Label", String(60), nullable=False)
    tier: Mapped[str] = mapped_column("Tier", String(2), nullable=False)
    # CHECK: T0 / T1 / T2


class FocusArea(Base):
    """Câu 4: vùng cơ thể quan tâm."""

    __tablename__ = "FocusAreas"

    code: Mapped[str] = mapped_column("AreaCode", String(20), primary_key=True)
    label: Mapped[str] = mapped_column("Label", String(40), nullable=False)


class FocusAreaAccessory(Base):
    """Bài tập phụ đề xuất kèm mỗi vùng tập trung."""

    __tablename__ = "FocusAreaAccessories"

    area_code: Mapped[str] = mapped_column("AreaCode", String(20), primary_key=True)
    exercise_id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)


class HealthIssue(Base):
    """Câu 11: vấn đề sức khoẻ cần điều chỉnh giáo án."""

    __tablename__ = "HealthIssues"

    code: Mapped[str] = mapped_column("IssueCode", String(30), primary_key=True)
    label_vi: Mapped[str] = mapped_column("LabelVi", String(80), nullable=False)
    extra_constraint: Mapped[str | None] = mapped_column("ExtraConstraint", String(255), nullable=True)
    force_beginner_pool: Mapped[int] = mapped_column(
        "ForceBeginnerPool", SmallInteger, nullable=False, default=0
    )


class HealthIssueExclusion(Base):
    """Bài bị cấm hoàn toàn khi user có vấn đề sức khoẻ này."""

    __tablename__ = "HealthIssueExclusions"

    issue_code: Mapped[str] = mapped_column("IssueCode", String(30), primary_key=True)
    exercise_id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)


class HealthIssueReplacement(Base):
    """Bài thay thế khi bài gốc bị loại do vấn đề sức khoẻ."""

    __tablename__ = "HealthIssueReplacements"

    issue_code: Mapped[str] = mapped_column("IssueCode", String(30), primary_key=True)
    exercise_id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)


class VolumeModifier(Base):
    """Hệ số điều chỉnh khối lượng tập theo BMI / tuổi / mức vận động."""

    __tablename__ = "VolumeModifiers"

    id: Mapped[int] = mapped_column("ModifierId", primary_key=True)
    dimension: Mapped[str] = mapped_column("Dimension", String(10), nullable=False)
    min_value: Mapped[Decimal | None] = mapped_column("MinValue", Numeric(6, 2), nullable=True)
    max_value: Mapped[Decimal | None] = mapped_column("MaxValue", Numeric(6, 2), nullable=True)
    enum_value: Mapped[str | None] = mapped_column("EnumValue", String(20), nullable=True)
    multiplier: Mapped[Decimal] = mapped_column(
        "Multiplier", Numeric(3, 2), nullable=False, default=Decimal("1.00")
    )
    ramp_weeks: Mapped[int] = mapped_column("RampWeeks", SmallInteger, nullable=False, default=0)
    adjustment_note: Mapped[str | None] = mapped_column("AdjustmentNote", String(255), nullable=True)


class StartingLoadHint(Base):
    """Gợi ý tạ khởi điểm theo giới tính và bài tập."""

    __tablename__ = "StartingLoadHints"

    exercise_id: Mapped[int] = mapped_column("ExerciseId", primary_key=True)
    gender: Mapped[str] = mapped_column("Gender", String(10), primary_key=True)
    load_range: Mapped[str] = mapped_column("LoadRange", String(40), nullable=False)
