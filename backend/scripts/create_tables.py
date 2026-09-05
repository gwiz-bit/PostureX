"""Tao bang videos/workouts (Users/Roles do scripts/run_schema.py quan ly, khong dong o day)."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text

from app.core.database import Base, engine
from app.models import (  # noqa: F401 dang ky model de resolve FK
    device_token,
    email_otp,
    goal,
    notification,
    password_reset_token,
    role,
    user,
    user_profile,
    video,
    workout,
)

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
                Base.metadata.tables["device_tokens"],
            ],
            checkfirst=True,
        )
    print("Tables created successfully.")
    await engine.dispose()


asyncio.run(main())
