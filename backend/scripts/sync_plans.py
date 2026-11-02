"""Dua bang SubscriptionPlans ve dung 2 goi ban tren web: Free (0d) va Pro (59.000d).

Chay mot lan tren server co MySQL (hoac may dev noi duoc DB):
    python scripts/sync_plans.py [--dry-run]

- 'Free'    : giu, cap nhat mo ta (moi tinh nang, tru phan tich real-time).
- 'Pro'     : tao neu chua co; neu da co (ban cu 199.000d) thi doi gia ve 59.000d.
- Goi khac (vd 'Premium'): chi TAT (IsActive = 0), KHONG xoa — user cu co the dang
  tro toi no bang UserSubscriptions (khoa ngoai). `is_premium()` chi xet gia > 0
  nen ho van duoc dung toi het han.
"""

import argparse
import asyncio
from decimal import Decimal

from sqlalchemy import select

from app.core.database import AsyncSessionLocal
from app.models.subscription import SubscriptionPlan

FREE_FEATURES = "Toàn bộ tính năng và bài tập, không có phân tích tư thế thời gian thực"
PRO_FEATURES = "Tất cả tính năng của gói Free + phân tích tư thế thời gian thực bằng AI"
PRO_PRICE = Decimal("59000.00")


async def sync(dry_run: bool = False) -> None:
    async with AsyncSessionLocal() as db:
        plans = {p.name.lower(): p for p in (await db.execute(select(SubscriptionPlan))).scalars()}

        changes: list[str] = []

        free = plans.get("free")
        if free is None:
            db.add(SubscriptionPlan(name="Free", price_monthly=Decimal("0"), currency="VND",
                                    features=FREE_FEATURES, is_active=True))
            changes.append("tao goi Free")
        elif free.features != FREE_FEATURES or not free.is_active:
            free.features, free.is_active = FREE_FEATURES, True
            changes.append("cap nhat mo ta goi Free")

        pro = plans.get("pro")
        if pro is None:
            db.add(SubscriptionPlan(name="Pro", price_monthly=PRO_PRICE, currency="VND",
                                    features=PRO_FEATURES, is_active=True))
            changes.append("tao goi Pro 59.000d")
        elif pro.price_monthly != PRO_PRICE or pro.features != PRO_FEATURES or not pro.is_active:
            changes.append(f"goi Pro: {pro.price_monthly} -> {PRO_PRICE}, bat lai, cap nhat mo ta")
            pro.price_monthly, pro.features, pro.is_active = PRO_PRICE, PRO_FEATURES, True

        for key, plan in plans.items():
            if key not in ("free", "pro") and plan.is_active:
                plan.is_active = False
                changes.append(f"tat goi '{plan.name}' (giu lai trong DB)")

        if not changes:
            print("Bang SubscriptionPlans da dung 2 goi Free/Pro, khong can doi gi.")
            return
        for line in changes:
            print(("[dry-run] " if dry_run else "") + line)
        if dry_run:
            await db.rollback()
        else:
            await db.commit()
            print("Da luu.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="chi in ra, khong ghi")
    asyncio.run(sync(parser.parse_args().dry_run))
