"""Tao bang videos/workouts (Users/Roles do sql/run_schema.py quan ly, khong dong o day)."""

import asyncio

from sqlalchemy import select, text

from app.core.database import AsyncSessionLocal, Base, engine
from app.models import (  # noqa: F401 dang ky model de resolve FK
    device_token,
    email_otp,
    goal,
    notification,
    password_reset_token,
    plan,
    promo_code,
    role,
    transaction,
    user,
    user_profile,
    video,
    workout,
)
from app.models.plan import Plan

# Chi drop/tao lai videos/workouts — Users/Roles/UserProfiles/Goals la bang
# ngoai, dung chung voi schema PostureX (sql/postureX123_schema.sql). Luu y:
# MySQL o day co lower_case_table_names=1 nen "Users" va "users" la CUNG MOT
# bang — tuyet doi khong duoc them "users" vao DROP_SQL nay.
# email_otps, password_reset_tokens va device_tokens KHONG nam trong DROP_SQL
# (khong drop moi lan chay): xoa email_otps/password_reset_tokens la mat OTP/token
# dang cho xu ly cua nguoi dung khac; xoa device_tokens la moi thiet bi mat dang ky,
# nguoi dung ngung nhan push cho toi khi mo lai app.
DROP_SQL = """
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS videos;
DROP TABLE IF EXISTS workouts;
SET FOREIGN_KEY_CHECKS = 1;
"""


async def main() -> None:
    async with engine.begin() as conn:
        for statement in DROP_SQL.strip().split(";"):
            statement = statement.strip()
            if statement:
                await conn.execute(text(statement))
        await conn.run_sync(
            Base.metadata.create_all,
            tables=[
                Base.metadata.tables["videos"],
                Base.metadata.tables["workouts"],
                Base.metadata.tables["email_otps"],
                Base.metadata.tables["password_reset_tokens"],
                Base.metadata.tables["plans"],
                Base.metadata.tables["promo_codes"],
                Base.metadata.tables["transactions"],
                Base.metadata.tables["device_tokens"],
            ],
            checkfirst=True,
        )
    print("Tables created successfully.")
    await seed_plans()
    await engine.dispose()


async def seed_plans() -> None:
    """Chèn 3 gói thật (Free/Advanced/Pro) khớp đúng nội dung đã hiển thị
    tĩnh ở lib/screens/subscription_screen.dart — idempotent, chỉ chèn nếu
    bảng plans đang trống (không đụng gì nếu admin đã tự sửa/tạo gói)."""
    async with AsyncSessionLocal() as db:
        existing = (await db.execute(select(Plan.id))).first()
        if existing is not None:
            print("plans da co du lieu, bo qua seed.")
            return

        db.add_all([
            Plan(
                name="Free",
                tagline="Get started with the basics",
                price_vnd=0,
                duration_months=0,
                features="Access to basic exercise library\n"
                "Up to 3 workouts per day\n"
                "Basic posture tracking\n"
                "Progress overview",
            ),
            Plan(
                name="Advanced",
                tagline="For serious fitness enthusiasts",
                price_vnd=199_000,
                duration_months=1,
                features="Access to advanced exercise library\n"
                "Unlimited workouts per day\n"
                "Personalized workout plans\n"
                "Detailed progress analytics\n"
                "Priority support",
            ),
            Plan(
                name="Pro",
                tagline="AI-powered coaching experience",
                price_vnd=299_000,
                duration_months=1,
                features="AI camera movement analysis\n"
                "Real-time posture correction\n"
                "Voice guidance & error feedback\n"
                "Detailed rep-by-rep reports\n"
                "Early access to new features",
            ),
        ])
        await db.commit()
    print("Da seed 3 goi Free/Advanced/Pro.")


asyncio.run(main())
