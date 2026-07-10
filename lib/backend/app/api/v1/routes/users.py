"""Endpoints quản lý thông tin user."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import hash_password
from app.crud.profile import get_profile, upsert_profile
from app.models.user import User
from app.schemas.profile import ProfileOut, ProfileUpdate
from app.schemas.user import UserOut, UserUpdate
from app.utils.deps import get_current_user

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserOut)
async def get_me(current_user: User = Depends(get_current_user)) -> UserOut:
    """Lấy thông tin user đang đăng nhập."""
    return UserOut.model_validate(current_user)


@router.patch("/me", response_model=UserOut)
async def update_me(
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> UserOut:
    """Chỉnh sửa hồ sơ cá nhân (tên, mật khẩu)."""
    if data.full_name is not None:
        current_user.full_name = data.full_name
    if data.password is not None:
        current_user.hashed_password = hash_password(data.password)
    await db.flush()
    return UserOut.model_validate(current_user)


@router.get("/me/profile", response_model=ProfileOut)
async def get_my_profile(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProfileOut:
    """Lấy hồ sơ thể chất + mục tiêu tập luyện (từ onboarding)."""
    return await get_profile(db, current_user.id)


@router.put("/me/profile", response_model=ProfileOut)
async def update_my_profile(
    data: ProfileUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> ProfileOut:
    """Lưu hồ sơ thể chất + mục tiêu tập luyện đã chọn khi onboarding."""
    return await upsert_profile(db, current_user.id, data)
