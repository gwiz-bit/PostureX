"""Tao bang videos/workouts (Users/Roles do sql/run_schema.py quan ly, khong dong o day)."""

import asyncio

from sqlalchemy import text

from app.core.database import Base, engine
from app.models import (  # noqa: F401 dang ky model de resolve FK
    device_token,
    email_otp,
    goal,
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
# email_otps va device_tokens KHONG nam trong DROP_SQL (khong drop moi lan chay):
# xoa email_otps la mat OTP dang cho xac thuc cua nguoi khac; xoa device_tokens la
# moi thiet bi mat dang ky, nguoi dung ngung nhan push cho toi khi mo lai app.
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
                Base.metadata.tables["device_tokens"],
            ],
            checkfirst=True,
        )
    print("Tables created successfully.")
    await engine.dispose()


asyncio.run(main())
