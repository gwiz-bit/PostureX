"""Xoá tài khoản người dùng — dùng chung cho cả hai đường vào: nút "Xoá tài
khoản" trong app (DELETE /users/me) và trang web công khai /delete-account
(xác nhận bằng mã gửi qua email).

Đây là xoá THẬT chứ không phải vô hiệu hoá: bản ghi người dùng và mọi dữ liệu
gắn với họ bị loại khỏi DB, file video tải lên bị xoá khỏi ổ đĩa. Phần duy nhất
còn lại là hoá đơn thanh toán đã hoàn tất, được chép sang `payment_archive` dưới
dạng ẩn danh (không còn bất cứ định danh nào) để tuân thủ nghĩa vụ lưu trữ
chứng từ kế toán/thuế. Phần này phải khớp với những gì nói trong
docs/privacy-policy.html và app/web/delete_account.html — đổi một nơi thì sửa cả
hai.
"""

import logging
from pathlib import Path

from sqlalchemy import delete, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.account_deletion import AccountDeletionRequest, PaymentArchive
from app.models.coach_report import CoachReport
from app.models.notification import Notification
from app.models.subscription import (
    PAYMENT_PAID,
    Payment,
    SubscriptionPlan,
    UserSubscription,
)
from app.models.user import User
from app.models.video import Video

logger = logging.getLogger(__name__)

# Trạng thái hoá đơn cần giữ lại. Đơn Pending/Failed chưa từng phát sinh tiền
# nên không có nghĩa vụ lưu trữ — bị xoá cùng tài khoản.
_RETAINED_PAYMENT_STATUSES = (PAYMENT_PAID, "Refunded")


async def _archive_payments(db: AsyncSession, user_id: int) -> int:
    """Chép hoá đơn đã thanh toán của user sang bảng ẩn danh. Trả về số bản ghi."""
    rows = (
        await db.execute(
            select(Payment, SubscriptionPlan.name)
            .join(UserSubscription, Payment.user_subscription_id == UserSubscription.id)
            .join(SubscriptionPlan, UserSubscription.plan_id == SubscriptionPlan.id)
            .where(
                UserSubscription.user_id == user_id,
                Payment.status.in_(_RETAINED_PAYMENT_STATUSES),
            )
        )
    ).all()
    for payment, plan_name in rows:
        db.add(
            PaymentArchive(
                transaction_no=payment.transaction_no,
                plan_name=plan_name,
                amount=payment.amount,
                currency=payment.currency,
                payment_method=payment.payment_method,
                status=payment.status,
                paid_at=payment.paid_at,
                created_at=payment.created_at,
            )
        )
    return len(rows)


def _delete_video_files(paths: list[str]) -> None:
    """Xoá file video khỏi ổ đĩa. Chỉ đụng tới file nằm trong thư mục lưu video,
    phòng khi một dòng DB cũ/sai trỏ ra ngoài."""
    storage_dir = settings.get_video_storage_path().resolve()
    for raw in paths:
        try:
            path = Path(raw).resolve()
            if storage_dir in path.parents:
                path.unlink(missing_ok=True)
            else:
                logger.warning("Bỏ qua file video ngoài thư mục lưu trữ: %s", raw)
        except OSError as e:
            logger.error("Không xoá được file video %s: %s", raw, e)


async def delete_user_account(db: AsyncSession, user: User) -> None:
    """Xoá user và toàn bộ dữ liệu của họ. Commit trong hàm này, rồi mới xoá file
    video — nếu DB lỗi thì file còn nguyên và người dùng được báo lỗi để thử lại,
    thay vì mất file mà tài khoản vẫn còn."""
    uid = user.id

    video_paths = list((await db.execute(select(Video.file_path).where(Video.user_id == uid))).scalars())

    await _archive_payments(db, uid)

    # Bảng không có ON DELETE CASCADE ở tầng DB — xoá tay trước khi xoá user.
    for table, column in (
        ("coach_messages", "user_id"),
        ("device_tokens", "user_id"),
        ("WorkoutPlans", "UserId"),
        ("videos", "user_id"),
        ("workouts", "user_id"),
    ):
        await db.execute(text(f"DELETE FROM {table} WHERE {column} = :uid"), {"uid": uid})  # noqa: S608

    # Các bảng này có cascade trong schema SQL, nhưng DB thật có thể lệch so với
    # file schema; xoá tường minh để việc xoá không phụ thuộc vào điều đó.
    await db.execute(delete(AccountDeletionRequest).where(AccountDeletionRequest.user_id == uid))
    await db.execute(delete(CoachReport).where(CoachReport.user_id == uid))
    await db.execute(delete(Notification).where(Notification.user_id == uid))
    sub_ids = select(UserSubscription.id).where(UserSubscription.user_id == uid)
    await db.execute(delete(Payment).where(Payment.user_subscription_id.in_(sub_ids)))
    await db.execute(delete(UserSubscription).where(UserSubscription.user_id == uid))

    # Nhật ký hệ thống: giữ dòng log nhưng cắt liên kết tới người dùng.
    # AuditLogs chỉ có UserId làm cột định danh người dùng (xem
    # sql/postureX123_schema.sql) — EntityName/EntityId/Details mô tả đối tượng
    # bị tác động (ví dụ "Users"/<id>), không phải thông tin cá nhân của người
    # thực hiện hành động, nên không cần xoá.
    await db.execute(
        text("UPDATE AuditLogs SET UserId = NULL WHERE UserId = :uid"),
        {"uid": uid},
    )

    # Xoá bằng câu lệnh Core, không qua db.delete(): xoá qua ORM sẽ cố nạp các
    # quan hệ `videos`/`workouts` (lazy-load bất đồng bộ) để gỡ khoá ngoại.
    await db.execute(delete(User).where(User.id == uid))
    db.expunge(user)
    await db.commit()

    _delete_video_files(video_paths)
    logger.info("Đã xoá tài khoản user_id=%s (%d video)", uid, len(video_paths))
