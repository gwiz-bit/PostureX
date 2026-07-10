"""Script kiem tra ket noi toi MySQL local.

Doc cau hinh truc tiep tu file .env (qua app.core.config.settings) de
khong bi lech voi cau hinh that cua app — sua o .env, khong sua o day.
"""

import asyncio

import aiomysql

from app.core.config import settings


async def main() -> None:
    print("Dang ket noi...")
    print(f"  Host: {settings.DB_HOST}:{settings.DB_PORT}")
    print(f"  Database: {settings.DB_NAME}")
    print(f"  User: {settings.DB_USER}")
    try:
        conn = await aiomysql.connect(
            host=settings.DB_HOST,
            port=settings.DB_PORT,
            user=settings.DB_USER,
            password=settings.DB_PASSWORD,
            db=settings.DB_NAME,
        )
        cursor = await conn.cursor()
        await cursor.execute("SELECT VERSION();")
        row = await cursor.fetchone()
        print("KET NOI THANH CONG!")
        print("Phien ban MySQL:", row[0])
        await cursor.close()
        conn.close()
    except Exception as e:
        print("KET NOI THAT BAI")
        print("Chi tiet loi:", e)


asyncio.run(main())
