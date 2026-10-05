"""Hai bảng phục vụ xoá tài khoản, do backend tự quản lý (tạo qua
scripts/ensure_tables.py, không nằm trong sql/postureX123_schema.sql gốc).

- AccountDeletionRequest: mã xác nhận gửi qua email cho luồng xoá trên web
  (/delete-account) — dành cho người đã gỡ app. Lưu bản băm của mã, không lưu
  mã gốc. Xoá theo user (ON DELETE CASCADE) nên không để lại dấu vết gì sau khi
  tài khoản đã bị xoá.
- PaymentArchive: bản sao ĐÃ ẨN DANH của hoá đơn thanh toán, giữ lại để tuân thủ
  nghĩa vụ lưu trữ chứng từ kế toán/thuế. Cố tình KHÔNG có cột user nào, KHÔNG
  khoá ngoại tới Users và KHÔNG chép `PaymentGatewayLog` (phản hồi thô của cổng
  thanh toán có thể chứa thông tin cá nhân) — nên xoá tài khoản không kéo theo
  bảng này, và bản ghi trong đó không truy ngược được về người dùng.
"""

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AccountDeletionRequest(Base):
    __tablename__ = "account_deletion_requests"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("Users.UserId", ondelete="CASCADE"), nullable=False, index=True
    )
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)


class PaymentArchive(Base):
    __tablename__ = "payment_archive"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    # Mã giao dịch bên cổng thanh toán (MoMo) — để đối soát với sao kê khi cần.
    transaction_no: Mapped[str | None] = mapped_column(String(100), nullable=True, index=True)
    plan_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(50), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    archived_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, nullable=False)
