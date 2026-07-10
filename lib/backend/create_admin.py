"""Tao tai khoan admin dau tien cho he thong."""

import asyncio
import sys

from sqlalchemy import select

from app.core.database import AsyncSessionLocal, engine
from app.core.security import hash_password
from app.crud.role import get_role_by_name
from app.crud.user import generate_unique_username
from app.models.role import ADMIN_ROLE_NAME
from app.models import role as _, video as __, workout as ___  # noqa: F401 register all models
from app.models.user import User


async def create_admin(email: str, password: str, full_name: str = "Admin") -> None:
    async with AsyncSessionLocal() as db:
        admin_role = await get_role_by_name(db, ADMIN_ROLE_NAME)
        if admin_role is None:
            print("Loi: Role 'Admin' chua ton tai — chay `python sql/run_schema.py` truoc.")
            return

        result = await db.execute(select(User).where(User.email == email))
        existing = result.scalar_one_or_none()

        if existing:
            if not existing.is_admin:
                existing.role = admin_role
                await db.commit()
                print(f"Updated existing user '{email}' to admin.")
            else:
                print(f"User '{email}' is already an admin.")
            return

        admin_user = User(
            email=email,
            username=await generate_unique_username(db, email),
            hashed_password=hash_password(password),
            full_name=full_name,
            is_active=True,
            role=admin_role,
        )
        db.add(admin_user)
        await db.commit()
        print(f"Admin account created: {email}")

    await engine.dispose()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python create_admin.py <email> <password> [full_name]")
        print("Example: python create_admin.py admin@posturex.com Admin123 'Super Admin'")
        sys.exit(1)

    email_arg = sys.argv[1]
    pass_arg = sys.argv[2]
    name_arg = sys.argv[3] if len(sys.argv) > 3 else "Admin"

    asyncio.run(create_admin(email_arg, pass_arg, name_arg))
