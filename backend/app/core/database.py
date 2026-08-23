"""Async SQLAlchemy engine, session factory va Base model."""

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings

engine = create_async_engine(
    settings.get_database_url(),
    # pool_pre_ping tat: SQLAlchemy 2.0.36's aiomysql dialect goi
    # dbapi_connection.ping() thieu tham so 'reconnect', gay
    # "TypeError: ping() missing 1 required positional argument"
    # tren moi request. Khong anh huong chuc nang, chi mat kha nang
    # tu phat hien connection chet truoc khi dung.
    pool_pre_ping=False,
    echo=settings.DEBUG,
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    """Dependency tra ve async database session."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
