"""Models lưu câu trả lời onboarding của user.

Bốn bảng nhiều-nhiều: user ↔ mục tiêu, vùng tập, vấn đề sức khoẻ, dụng cụ.
"""

from __future__ import annotations

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserGoal(Base):
    """Mục tiêu người dùng chọn trong onboarding (câu 1)."""

    __tablename__ = "UserGoals"

    user_id: Mapped[int] = mapped_column("UserId", primary_key=True)
    goal_code: Mapped[str] = mapped_column("GoalCode", String(30), primary_key=True)


class UserFocusArea(Base):
    """Vùng cơ thể người dùng muốn tập trung (câu 4)."""

    __tablename__ = "UserFocusAreas"

    user_id: Mapped[int] = mapped_column("UserId", primary_key=True)
    area_code: Mapped[str] = mapped_column("AreaCode", String(20), primary_key=True)


class UserHealthIssue(Base):
    """Vấn đề sức khoẻ người dùng khai báo (câu 11)."""

    __tablename__ = "UserHealthIssues"

    user_id: Mapped[int] = mapped_column("UserId", primary_key=True)
    issue_code: Mapped[str] = mapped_column("IssueCode", String(30), primary_key=True)


class UserEquipment(Base):
    """Dụng cụ người dùng hiện có (câu 12)."""

    __tablename__ = "UserEquipment"

    user_id: Mapped[int] = mapped_column("UserId", primary_key=True)
    equipment_code: Mapped[str] = mapped_column("EquipmentCode", String(30), primary_key=True)
