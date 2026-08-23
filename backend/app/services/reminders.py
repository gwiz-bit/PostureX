"""Hai job định kỳ của BE-13: nhắc nghỉ giải lao & tổng kết hằng ngày.

Cố ý viết thành **hàm thuần nhận `db`**, không tự mở session. Nhờ vậy test gọi
thẳng được, không phải chờ tới 8 giờ tối hay giả lập scheduler. Phần lịch chạy
nằm riêng ở `app/core/scheduler.py`.

Cả hai job đều **chống trùng lặp**: trước khi gửi, hỏi DB xem người đó đã nhận
thông báo cùng loại trong khoảng thời gian đang xét chưa. Không có hàng rào này
thì mỗi lần uvicorn `--reload` khởi động lại, job có thể chạy lại và bắn thông
báo lần hai cho cùng một người.
"""

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.crud.notification import (
    TYPE_BREAK,
    TYPE_DAILY_SUMMARY,
    TYPE_SUBSCRIPTION_EXPIRY,
    create_notification,
    users_notified_since,
)
from app.crud.subscription import get_expiring_subscriptions, get_plan_by_id
from app.models.user import User
from app.models.workout import Workout
from app.utils.timezone import vn_day_start_utc, vn_now

logger = logging.getLogger(__name__)

# Đã nhắc nghỉ rồi thì im trong ngần này giờ — tránh làm phiền.
BREAK_REMINDER_COOLDOWN_HOURS = 3

# Nhắc gia hạn khi gói còn ngần này ngày.
EXPIRY_WARNING_DAYS = 3
# Trong ngần này ngày chỉ nhắc gia hạn MỘT lần. Cửa sổ cảnh báo là 3 ngày, nên
# đặt 7 để người dùng nhận đúng một lời nhắc cho mỗi chu kỳ, không phải 3 ngày
# liên tiếp bị nhắc.
EXPIRY_REMINDER_COOLDOWN_DAYS = 7


async def send_break_reminders(db: AsyncSession) -> int:
    """Nhắc những người **hôm nay chưa tập buổi nào** đứng dậy vận động.

    Quy tắc nhắm đối tượng (viết rõ ra vì plan chỉ ghi vỏn vẹn "nhắc nghỉ giải lao"):
    người dùng còn hoạt động + hôm nay chưa có buổi tập nào + trong
    [BREAK_REMINDER_COOLDOWN_HOURS] giờ qua chưa bị nhắc. Ai đã tập hôm nay thì
    thôi — nhắc họ "đứng dậy đi" là vô duyên.

    Trả về số thông báo đã gửi.
    """
    day_start = vn_day_start_utc()

    trained_today = select(Workout.user_id).where(Workout.created_at >= day_start)
    result = await db.execute(
        select(User.id).where(
            User.is_active.is_(True),
            User.id.not_in(trained_today),
        )
    )
    candidates = set(result.scalars().all())

    # Mốc so sánh phải tính theo UTC: cột `Notifications.CreatedAt` lưu UTC. Đưa
    # vào một mốc theo giờ VN thì lệch đúng 7 tiếng và hàng rào chống trùng mất
    # tác dụng (đã có test bắt được lỗi này).
    cooldown_start = datetime.now(timezone.utc) - timedelta(
        hours=BREAK_REMINDER_COOLDOWN_HOURS
    )
    recently_nudged = await users_notified_since(db, TYPE_BREAK, cooldown_start)
    targets = candidates - recently_nudged

    for user_id in targets:
        await create_notification(
            db,
            user_id=user_id,
            title="Đến giờ nghỉ giải lao",
            body="Hôm nay bạn chưa tập buổi nào. Đứng dậy vươn vai vài phút nhé.",
            type_=TYPE_BREAK,
        )

    logger.info("Nhắc nghỉ giải lao: gửi %d thông báo", len(targets))
    return len(targets)


async def send_daily_summaries(db: AsyncSession) -> int:
    """Gửi tổng kết cuối ngày cho những ai **có tập** hôm nay.

    Ai không tập buổi nào thì bỏ qua — họ đã nhận "nhắc nghỉ giải lao" rồi, gửi
    thêm một cái "hôm nay bạn tập 0 buổi" chỉ là cằn nhằn.

    Trả về số thông báo đã gửi.
    """
    day_start = vn_day_start_utc()

    result = await db.execute(
        select(
            Workout.user_id,
            func.count().label("sessions"),
            func.sum(Workout.total_reps).label("reps"),
            func.avg(Workout.accuracy_score).label("accuracy"),
        )
        .where(Workout.created_at >= day_start)
        .group_by(Workout.user_id)
    )
    stats = result.all()

    already_sent = await users_notified_since(db, TYPE_DAILY_SUMMARY, day_start)

    sent = 0
    for user_id, sessions, reps, accuracy in stats:
        if user_id in already_sent:
            continue

        parts = [f"{sessions} buổi tập", f"{int(reps or 0)} lần"]
        if accuracy is not None:
            parts.append(f"độ chính xác trung bình {float(accuracy):.0f}%")

        await create_notification(
            db,
            user_id=user_id,
            title="Tổng kết hôm nay",
            body=" · ".join(parts),
            type_=TYPE_DAILY_SUMMARY,
        )
        sent += 1

    logger.info("Tổng kết hằng ngày: gửi %d thông báo", sent)
    return sent


async def send_expiry_reminders(db: AsyncSession) -> int:
    """Nhắc những ai có gói sắp hết hạn trong [EXPIRY_WARNING_DAYS] ngày.

    Đây là công dụng **duy nhất** của cờ `AutoRenew` trong hệ thống hiện tại:
    Cổng thanh toán không trừ tiền định kỳ được, nên "tự động gia hạn" thực chất là "nhắc
    tôi gia hạn". Ai đã tự tắt gia hạn thì không nhắc — họ biết rồi.

    Trả về số thông báo đã gửi.
    """
    expiring = await get_expiring_subscriptions(db, within_days=EXPIRY_WARNING_DAYS)
    if not expiring:
        return 0

    cooldown_start = datetime.now(timezone.utc) - timedelta(
        days=EXPIRY_REMINDER_COOLDOWN_DAYS
    )
    already_warned = await users_notified_since(
        db, TYPE_SUBSCRIPTION_EXPIRY, cooldown_start
    )

    today = vn_now().date()
    sent = 0
    for subscription in expiring:
        if subscription.user_id in already_warned:
            continue

        plan = await get_plan_by_id(db, subscription.plan_id)
        days_left = (subscription.end_date - today).days
        when = "hôm nay" if days_left == 0 else f"sau {days_left} ngày"

        await create_notification(
            db,
            user_id=subscription.user_id,
            title=f"Gói {plan.name if plan else 'Premium'} sắp hết hạn",
            body=f"Gói của bạn hết hạn {when} ({subscription.end_date:%d/%m/%Y}). "
            "Gia hạn để không bị gián đoạn.",
            type_=TYPE_SUBSCRIPTION_EXPIRY,
        )
        sent += 1

    logger.info("Nhắc gia hạn: gửi %d thông báo", sent)
    return sent
