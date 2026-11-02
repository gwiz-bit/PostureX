"""Web (posturex1.com) bao sang app: user da tra tien goi Pro tren web.

Chi la cau noi server-to-server: web thu tien qua SePay roi goi endpoint nay de
app ghi vao `UserSubscriptions` — nhu vay `is_premium()` va man hinh Cai dat
nhan ra goi Pro. App KHONG tu ban goi (PAYMENTS_ENABLED van tat) va khong dan
nguoi dung sang web.

Xac thuc bang khoa dung chung `WEB_ACTIVATION_KEY` (header `X-Web-Key`), khong
dung token nguoi dung — web khong co token cua nguoi mua luc nhan IPN."""

import logging
import secrets

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.crud.notification import TYPE_PAYMENT, create_notification
from app.crud.subscription import activate_from_web, get_pro_plan
from app.crud.user import get_user_by_id
from app.schemas.subscription import WebActivationIn

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/internal", tags=["internal"])


def _require_web_key(x_web_key: str | None = Header(default=None)) -> None:
    expected = settings.WEB_ACTIVATION_KEY
    if not expected:
        # Chua cau hinh khoa = tinh nang tat. Khong de endpoint mo.
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Chua cau hinh kich hoat tu web.")
    if x_web_key is None or not secrets.compare_digest(x_web_key, expected):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Khoa khong hop le.")


@router.post("/web-subscription", dependencies=[Depends(_require_web_key)])
async def activate_web_subscription(
    data: WebActivationIn, db: AsyncSession = Depends(get_db)
) -> dict:
    user = await get_user_by_id(db, data.user_id)
    if user is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Khong tim thay user.")
    plan = await get_pro_plan(db)
    if plan is None:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, "Chua co goi Pro trong DB.")

    subscription, created = await activate_from_web(
        db, user.id, plan, data.invoice, data.amount, data.end_date
    )
    if created:
        await create_notification(
            db,
            user_id=user.id,
            title="Đã kích hoạt gói Pro",
            body=f"Gói Pro dùng được tới {data.end_date:%d/%m/%Y}.",
            type_=TYPE_PAYMENT,
        )
    logger.info(
        "Kich hoat goi Pro tu web: user=%d invoice=%s den %s (moi=%s)",
        user.id, data.invoice, data.end_date, created,
    )
    return {"ok": True, "created": created, "end_date": subscription.end_date.isoformat()}
