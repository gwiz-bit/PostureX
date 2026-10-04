import asyncio

from sqlalchemy import text

from app.core.database import AsyncSessionLocal

TEST_EMAILS = ("vdqv1132003@gmail.com", "testdev@example.com")


async def cleanup() -> None:
    async with AsyncSessionLocal() as db:
        for email in TEST_EMAILS:
            r = await db.execute(text("SELECT UserId FROM Users WHERE Email = :e"), {"e": email})
            row = r.fetchone()
            if not row:
                print(f"Not found: {email}")
                continue
            uid = row[0]
            for tbl in (
                "email_otps", "PasswordResetTokens", "DeviceTokens",
                "Notifications", "UserProfiles", "coach_messages",
                "Videos", "Workouts",
            ):
                try:
                    await db.execute(text(f"DELETE FROM `{tbl}` WHERE UserId = :uid"), {"uid": uid})
                except Exception:
                    pass
            await db.execute(text("DELETE FROM Users WHERE UserId = :uid"), {"uid": uid})
            print(f"Deleted {email} (id={uid})")
        await db.commit()
        print("Done.")


asyncio.run(cleanup())
