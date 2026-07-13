"""Model bảng Plans — các gói subscription (Free/Advanced/Pro).

Bảng do backend tự quản lý (như email_otps/videos), tạo qua
create_tables.py — không nằm trong sql/postureX123_schema.sql gốc.
"""

from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Plan(Base):
    __tablename__ = "plans"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    tagline: Mapped[str | None] = mapped_column(String(200), nullable=True)
    price_vnd: Mapped[int] = mapped_column(Integer, default=0)  # 0 = Free
    duration_months: Mapped[int] = mapped_column(Integer, default=1)
    # Danh sách tính năng, mỗi dòng 1 tính năng — đơn giản hơn 1 bảng con
    # riêng vì tính năng của mỗi gói không cần truy vấn/lọc riêng lẻ.
    features: Mapped[str] = mapped_column(Text, default="")
    # "Còn bán" hay không — khớp nút "Stop selling" đã có sẵn ở admin UI.
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
