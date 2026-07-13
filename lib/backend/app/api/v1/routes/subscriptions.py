"""Endpoints subscription cho user: xem gói, đăng ký gói (mock payment), thông báo của tôi."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import subscription as sub_crud
from app.models.user import User
from app.schemas.subscription import (
    NotificationOut,
    PlanOut,
    SubscribeRequest,
    TransactionOut,
)
from app.utils.deps import get_current_user

router = APIRouter(tags=["subscriptions"])


@router.get("/plans", response_model=list[PlanOut])
async def list_plans(db: AsyncSession = Depends(get_db)) -> list[PlanOut]:
    """Danh sách các gói subscription đang mở bán."""
    plans = await sub_crud.get_active_plans(db)
    return [PlanOut.model_validate(p) for p in plans]


@router.get("/plans/me", response_model=PlanOut | None)
async def get_my_plan(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> PlanOut | None:
    """Gói hiện tại của user (suy ra từ giao dịch thành công gần nhất)."""
    plan = await sub_crud.get_current_plan_for_user(db, current_user.id)
    return PlanOut.model_validate(plan) if plan is not None else None


@router.post("/subscriptions/subscribe", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def subscribe(
    data: SubscribeRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> TransactionOut:
    """Đăng ký một gói — mock payment, luôn thành công ngay lập tức."""
    plan = await sub_crud.get_plan_by_id(db, data.plan_id)
    if plan is None or not plan.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy gói.")

    amount = plan.price_vnd
    if data.promo_code:
        promo = await sub_crud.get_valid_promo_by_code(db, data.promo_code)
        if promo is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Mã giảm giá không hợp lệ hoặc đã hết hạn."
            )
        amount = round(amount * (100 - promo.discount_percent) / 100)

    tx = await sub_crud.create_transaction(db, current_user.id, plan, amount)
    return TransactionOut.model_validate(tx)


@router.get("/notifications/me", response_model=list[NotificationOut])
async def list_my_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[NotificationOut]:
    """Thông báo dành cho user hiện tại, lọc theo gói hiện tại (all/premium/free)."""
    notifs = await sub_crud.get_notifications_for_user(db, current_user.id)
    return [NotificationOut.model_validate(n) for n in notifs]
