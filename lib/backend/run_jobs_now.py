"""Chay tay cac job dinh ky cua BE-13, khong phai cho toi gio.

Scheduler that chi chay luc 10h/15h (nhac nghi) va 20h (tong ket). Khi test hoac
demo thi khong the ngoi cho — dung script nay de bat job chay ngay.

    python run_jobs_now.py break     # nhac nghi giai lao
    python run_jobs_now.py summary   # tong ket hang ngay
    python run_jobs_now.py expiry    # nhac goi sap het han
    python run_jobs_now.py all       # ca ba

Job co hang rao chong trung lap: chay lai lan hai trong cung khoang thoi gian se
KHONG gui them thong bao. Muon thay no gui lai thi xoa thong bao cu trong DB.
"""

import asyncio
import sys

from app.core.database import AsyncSessionLocal, engine
from app.models import notification as _n  # noqa: F401  dang ky model
from app.models import role as _r  # noqa: F401
from app.models import subscription as _s  # noqa: F401
from app.models import user as _u  # noqa: F401
from app.models import video as _v  # noqa: F401
from app.models import workout as _w  # noqa: F401
from app.services.reminders import (
    send_break_reminders,
    send_daily_summaries,
    send_expiry_reminders,
)

JOBS = ("break", "summary", "expiry", "all")


async def main(job: str) -> None:
    async with AsyncSessionLocal() as db:
        if job in ("break", "all"):
            sent = await send_break_reminders(db)
            print(f"Nhac nghi giai lao: da gui {sent} thong bao")

        if job in ("summary", "all"):
            sent = await send_daily_summaries(db)
            print(f"Tong ket hang ngay: da gui {sent} thong bao")

        if job in ("expiry", "all"):
            sent = await send_expiry_reminders(db)
            print(f"Nhac goi sap het han: da gui {sent} thong bao")

        await db.commit()

    await engine.dispose()


if __name__ == "__main__":
    job = sys.argv[1] if len(sys.argv) > 1 else "all"
    if job not in JOBS:
        print(f"Job khong hop le: {job}. Chon: {' | '.join(JOBS)}")
        sys.exit(1)

    asyncio.run(main(job))
