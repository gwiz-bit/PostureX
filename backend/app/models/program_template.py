"""Models giáo án mẫu (ProgramTemplates, TemplateSessions, TemplateSlots,
SlotDefaultExercises, TemplateProgression).

Admin seed một lần. Người dùng không bao giờ ghi vào mấy bảng này.
TemplateSlots là bảng LÕI: ô bài tập chỉ biết MovementRole (loại vận động)
chứ không biết bài cụ thể — bài được chốt khi sinh giáo án cho user.
"""

from __future__ import annotations

from sqlalchemy import ForeignKey, SmallInteger, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ProgramTemplate(Base):
    """Giáo án mẫu — P01..P08, mỗi cái là một strategy tổng thể."""

    __tablename__ = "ProgramTemplates"

    code: Mapped[str] = mapped_column("ProgramCode", String(3), primary_key=True)
    direction: Mapped[str] = mapped_column("Direction", String(20), nullable=False)
    sessions_per_week: Mapped[int] = mapped_column("SessionsPerWeek", SmallInteger, nullable=False)
    split_name: Mapped[str] = mapped_column("SplitName", String(60), nullable=False)
    min_level: Mapped[str] = mapped_column("MinLevel", String(20), nullable=False)
    description: Mapped[str | None] = mapped_column("Description", String(1000), nullable=True)
    is_active: Mapped[int] = mapped_column("IsActive", SmallInteger, nullable=False, default=1)


class TemplateSession(Base):
    """Một buổi tập trong giáo án mẫu (vd Upper Push, Lower Pull)."""

    __tablename__ = "TemplateSessions"

    id: Mapped[int] = mapped_column("TemplateSessionId", primary_key=True)
    program_code: Mapped[str] = mapped_column(
        "ProgramCode", String(3),
        ForeignKey("ProgramTemplates.ProgramCode", ondelete="CASCADE"),
        nullable=False,
    )
    session_no: Mapped[int] = mapped_column("SessionNo", SmallInteger, nullable=False)
    session_name: Mapped[str] = mapped_column("SessionName", String(60), nullable=False)
    focus: Mapped[str | None] = mapped_column("Focus", String(120), nullable=True)
    est_minutes: Mapped[int | None] = mapped_column("EstMinutes", SmallInteger, nullable=True)


class TemplateSlot(Base):
    """Ô bài tập trong buổi mẫu — trỏ tới MovementRole, không phải bài cụ thể."""

    __tablename__ = "TemplateSlots"

    id: Mapped[int] = mapped_column("SlotId", primary_key=True)
    template_session_id: Mapped[int] = mapped_column(
        "TemplateSessionId",
        ForeignKey("TemplateSessions.TemplateSessionId", ondelete="CASCADE"),
        nullable=False,
    )
    slot_no: Mapped[int] = mapped_column("SlotNo", SmallInteger, nullable=False)
    movement_role_id: Mapped[int] = mapped_column(
        "MovementRoleId", ForeignKey("MovementRoles.MovementRoleId"), nullable=False
    )
    slot_label: Mapped[str | None] = mapped_column("SlotLabel", String(60), nullable=True)
    base_sets: Mapped[int] = mapped_column("BaseSets", SmallInteger, nullable=False)
    rep_scheme: Mapped[str] = mapped_column("RepScheme", String(30), nullable=False)
    rest_seconds: Mapped[int] = mapped_column("RestSeconds", SmallInteger, nullable=False)
    superset_group: Mapped[int | None] = mapped_column("SupersetGroup", SmallInteger, nullable=True)
    t0_warning: Mapped[str | None] = mapped_column("T0Warning", String(255), nullable=True)
    note: Mapped[str | None] = mapped_column("Note", String(255), nullable=True)


class SlotDefaultExercise(Base):
    """Bài mặc định của mỗi ô, một dòng cho mỗi mức dụng cụ."""

    __tablename__ = "SlotDefaultExercises"

    slot_id: Mapped[int] = mapped_column(
        "SlotId", ForeignKey("TemplateSlots.SlotId", ondelete="CASCADE"), primary_key=True
    )
    equipment_tier: Mapped[str] = mapped_column("EquipmentTier", String(2), primary_key=True)
    exercise_id: Mapped[int] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId"), nullable=False
    )


class TemplateProgression(Base):
    """Lộ trình 4 tuần: khối lượng, sets, hướng dẫn theo tuần."""

    __tablename__ = "TemplateProgression"

    program_code: Mapped[str] = mapped_column(
        "ProgramCode", String(3),
        ForeignKey("ProgramTemplates.ProgramCode", ondelete="CASCADE"),
        primary_key=True,
    )
    week_no: Mapped[int] = mapped_column("WeekNo", SmallInteger, primary_key=True)
    volume_pct: Mapped[str] = mapped_column("VolumePct", String(12), nullable=False)
    sets_main: Mapped[str] = mapped_column("SetsMain", String(12), nullable=False)
    sets_accessory: Mapped[str] = mapped_column("SetsAccessory", String(12), nullable=False)
    load_rule: Mapped[str] = mapped_column("LoadRule", String(80), nullable=False)
    cardio_prescription: Mapped[str | None] = mapped_column("CardioPrescription", String(120), nullable=True)
    instruction: Mapped[str | None] = mapped_column("Instruction", String(1000), nullable=True)
