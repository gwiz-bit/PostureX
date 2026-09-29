"""Model bảng MovementRoles — vai trò vận động.

Đây là bảng quan trọng nhất được thêm vào v2. Ô trong giáo án mẫu (TemplateSlots)
trỏ tới VAI TRÒ chứ không trỏ tới bài cụ thể, nên đổi bài chỉ là tìm bài khác
cùng MovementRoleId.
"""

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class MovementRole(Base):
    """Vai trò vận động — vd HorizontalPush, HipHinge, QuadDominant."""

    __tablename__ = "MovementRoles"

    id: Mapped[int] = mapped_column("MovementRoleId", primary_key=True)
    code: Mapped[str] = mapped_column("Code", String(40), nullable=False, unique=True)
    name_vi: Mapped[str] = mapped_column("NameVi", String(60), nullable=False)
    name_en: Mapped[str] = mapped_column("NameEn", String(60), nullable=False)
    category: Mapped[str] = mapped_column("Category", String(20), nullable=False)
    # CHECK: Compound / Isolation / Core / Cardio / Mobility
