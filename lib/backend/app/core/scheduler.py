"""Lịch chạy hai job của BE-13 (APScheduler).

Job **không** dùng chung session DB với request — mỗi lần chạy tự mở session
riêng rồi commit, vì nó chạy ngoài vòng đời request (không có `get_db`).

Giới hạn cần biết, đừng nhầm là bug:
  • Server tắt thì job **không chạy**. Đây là scheduler trong tiến trình, không
    phải cron của hệ điều hành. Backend dev chỉ bật khi làm việc, nên tổng kết
    20h sẽ bị bỏ lỡ nếu lúc đó máy tắt. Muốn chắc chắn thì phải đẩy sang cron
    thật / cloud scheduler khi triển khai.
  • Chạy nhiều worker (`--workers 2`) thì **mỗi worker có scheduler riêng** →
    job chạy 2 lần. Hàng rào chống trùng nằm ở tầng DB
    (`users_notified_since`), nên vẫn không gửi trùng thông báo — nhưng biết mà
    tránh vẫn hơn.
"""

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.services.reminders import (
    send_break_reminders,
    send_daily_summaries,
    send_expiry_reminders,
)
from app.utils.timezone import VN_TZ

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None


async def _run_break_reminders() -> None:
    async with AsyncSessionLocal() as db:
        await send_break_reminders(db)
        await db.commit()


async def _run_daily_summaries() -> None:
    async with AsyncSessionLocal() as db:
        await send_daily_summaries(db)
        await db.commit()


async def _run_expiry_reminders() -> None:
    async with AsyncSessionLocal() as db:
        await send_expiry_reminders(db)
        await db.commit()


def start_scheduler() -> None:
    global _scheduler
    if not settings.REMINDERS_ENABLED:
        logger.info("Scheduler tắt (REMINDERS_ENABLED=false).")
        return
    if _scheduler is not None:
        return

    _scheduler = AsyncIOScheduler(timezone=VN_TZ)

    # Nhắc nghỉ: vài mốc trong giờ làm việc, không rải đều cả ngày.
    _scheduler.add_job(
        _run_break_reminders,
        CronTrigger(hour=settings.BREAK_REMINDER_HOURS, minute=0, timezone=VN_TZ),
        id="break_reminders",
        # coalesce: bỏ lỡ nhiều lần (server tắt lâu) thì chỉ chạy bù ĐÚNG MỘT lần,
        # không dồn 5 lần bắn liên tiếp lúc server vừa bật.
        coalesce=True,
        max_instances=1,
        replace_existing=True,
    )

    _scheduler.add_job(
        _run_daily_summaries,
        CronTrigger(hour=settings.DAILY_SUMMARY_HOUR, minute=0, timezone=VN_TZ),
        id="daily_summaries",
        coalesce=True,
        max_instances=1,
        replace_existing=True,
    )

    # Nhắc gia hạn: 9h sáng, tách khỏi tổng kết tối cho khỏi dồn thông báo.
    _scheduler.add_job(
        _run_expiry_reminders,
        CronTrigger(hour=9, minute=0, timezone=VN_TZ),
        id="expiry_reminders",
        coalesce=True,
        max_instances=1,
        replace_existing=True,
    )

    _scheduler.start()
    logger.info(
        "Scheduler đã bật — nhắc nghỉ %s giờ, tổng kết %d giờ, nhắc gia hạn 9 giờ (giờ VN).",
        settings.BREAK_REMINDER_HOURS,
        settings.DAILY_SUMMARY_HOUR,
    )


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("Scheduler đã tắt.")
