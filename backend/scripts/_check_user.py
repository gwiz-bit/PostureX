import asyncio
from sqlalchemy import text
from app.core.database import AsyncSessionLocal

async def check():
    async with AsyncSessionLocal() as db:
        # Get columns
        r = await db.execute(text("SHOW COLUMNS FROM Users"))
        cols = [row[0] for row in r.fetchall()]
        print("Columns:", cols)

        # Find user
        r2 = await db.execute(
            text("SELECT UserId, Email FROM Users WHERE Email = :e"),
            {"e": "vdqv1132003@gmail.com"}
        )
        row = r2.fetchone()
        if row:
            print(f"User found: id={row[0]}")
        else:
            print("NOT FOUND in DB")

asyncio.run(check())
