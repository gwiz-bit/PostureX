"""Endpoints gói cước & thanh toán VNPay."""

import logging
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.crud.notification import TYPE_PAYMENT, TYPE_SUBSCRIPTION, create_notification
from app.crud.subscription import (
    activate_subscription,
    create_pending_order,
    get_active_subscription,
    get_payment_by_id,
    get_plan_by_id,
    get_subscription_by_id,
    list_active_plans,
    list_payments,
    mark_payment_failed,
    set_auto_renew,
)
from app.models.subscription import PAYMENT_PAID
from app.models.user import User
from app.schemas.subscription import (
    CheckoutIn,
    CheckoutOut,
    MySubscriptionOut,
    PaymentOut,
    PlanOut,
)
from app.services import vnpay
from app.utils.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(tags=["subscriptions"])


@router.get("/subscriptions/plans", response_model=list[PlanOut])
async def list_plans(db: AsyncSession = Depends(get_db)) -> list[PlanOut]:
    """Danh sách gói đang bán. Không cần đăng nhập — giá là thông tin công khai."""
    plans = await list_active_plans(db)
    return [PlanOut.model_validate(p) for p in plans]


@router.get("/subscriptions/me", response_model=MySubscriptionOut | None)
async def my_subscription(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MySubscriptionOut | None:
    """Gói đang dùng của user hiện tại — `null` nếu chưa mua gói nào."""
    subscription = await get_active_subscription(db, current_user.id)
    if subscription is None:
        return None

    return await _to_out(db, subscription)


@router.post("/subscriptions/cancel", response_model=MySubscriptionOut)
async def cancel_subscription(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MySubscriptionOut:
    """Huỷ tự động gia hạn.

    **Không cắt quyền ngay.** Người dùng đã trả tiền tới `end_date` nên gói vẫn
    chạy tới ngày đó rồi mới tự hết hạn — cắt ngay là ăn chặn ngày họ đã mua.
    """
    subscription = await get_active_subscription(db, current_user.id)
    if subscription is None:
        raise HTTPException(status_code=404, detail="Bạn không có gói nào đang dùng.")

    if not subscription.auto_renew:
        raise HTTPException(status_code=400, detail="Gói này đã tắt tự động gia hạn.")

    await set_auto_renew(db, subscription, False)
    plan = await get_plan_by_id(db, subscription.plan_id)
    await create_notification(
        db,
        user_id=current_user.id,
        title="Đã huỷ tự động gia hạn",
        body=f"Gói {plan.name if plan else 'Premium'} vẫn dùng được tới "
        f"{subscription.end_date:%d/%m/%Y}.",
        type_=TYPE_SUBSCRIPTION,
    )
    logger.info("User %d huỷ tự động gia hạn gói #%d", current_user.id, subscription.id)
    return await _to_out(db, subscription)


@router.post("/subscriptions/resume", response_model=MySubscriptionOut)
async def resume_subscription(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> MySubscriptionOut:
    """Bật lại tự động gia hạn (đổi ý sau khi huỷ)."""
    subscription = await get_active_subscription(db, current_user.id)
    if subscription is None:
        raise HTTPException(status_code=404, detail="Bạn không có gói nào đang dùng.")

    await set_auto_renew(db, subscription, True)
    return await _to_out(db, subscription)


@router.get("/payments", response_model=list[PaymentOut])
async def payment_history(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[PaymentOut]:
    """Lịch sử thanh toán của user, mới nhất trước."""
    payments = await list_payments(db, current_user.id)
    return [PaymentOut.model_validate(p) for p in payments]


async def _to_out(db: AsyncSession, subscription) -> MySubscriptionOut:
    plan = await get_plan_by_id(db, subscription.plan_id)
    days_left = (
        (subscription.end_date - date.today()).days
        if subscription.end_date is not None
        else None
    )
    return MySubscriptionOut(
        id=subscription.id,
        plan_id=subscription.plan_id,
        plan_name=plan.name if plan else "Unknown",
        status=subscription.status,
        start_date=subscription.start_date,
        end_date=subscription.end_date,
        auto_renew=subscription.auto_renew,
        days_left=days_left,
    )


@router.post("/subscriptions/checkout", response_model=CheckoutOut)
async def checkout(
    data: CheckoutIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> CheckoutOut:
    """Tạo đơn chờ thanh toán và trả về URL thanh toán VNPay."""
    if not settings.vnpay_configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Chưa cấu hình VNPay trên server (thiếu TmnCode/HashSecret).",
        )

    plan = await get_plan_by_id(db, data.plan_id)
    if plan is None or not plan.is_active:
        raise HTTPException(status_code=404, detail="Không tìm thấy gói cước.")

    # Gói miễn phí không đi qua cổng thanh toán — chặn ở đây thay vì tạo ra một
    # đơn 0đ mà VNPay sẽ từ chối.
    if plan.price_monthly <= 0:
        raise HTTPException(status_code=400, detail="Gói miễn phí không cần thanh toán.")

    subscription, payment = await create_pending_order(db, current_user.id, plan)

    pay_url = vnpay.build_payment_url(
        pay_url=settings.VNPAY_PAY_URL,
        tmn_code=settings.VNPAY_TMN_CODE,
        hash_secret=settings.VNPAY_HASH_SECRET,
        amount_vnd=int(plan.price_monthly),
        txn_ref=str(payment.id),
        order_info=f"Thanh toan goi {plan.name}",
        return_url=settings.VNPAY_RETURN_URL,
        client_ip=request.client.host if request.client else "127.0.0.1",
    )
    logger.info(
        "Tạo đơn thanh toán #%d cho user %d — gói %s", payment.id, current_user.id, plan.name
    )
    return CheckoutOut(payment_id=payment.id, pay_url=pay_url)


@router.get("/payments/vnpay/return", response_class=HTMLResponse)
async def vnpay_return(request: Request, db: AsyncSession = Depends(get_db)) -> HTMLResponse:
    """VNPay redirect trình duyệt người dùng về đây sau khi thanh toán.

    **Không có auth** — VNPay không mang theo token. Danh tính đơn hàng lấy từ
    `vnp_TxnRef` (= PaymentId), và tính toàn vẹn được bảo đảm bằng chữ ký HMAC:
    không có HashSecret thì không giả mạo được callback này.

    Đây là kênh *ReturnUrl* (do trình duyệt gọi). Production nên xử lý thêm
    *IPN* (VNPay gọi server-to-server) vì ReturnUrl sẽ không chạy nếu người dùng
    tắt app ngay sau khi trả tiền. IPN cần URL công khai nên không dùng được khi
    chạy localhost — vì vậy ở đây kích hoạt gói luôn tại ReturnUrl.
    """
    params = dict(request.query_params)
    gateway_log = str(request.query_params)

    if not vnpay.verify_signature(params, settings.VNPAY_HASH_SECRET):
        logger.warning("Callback VNPay có chữ ký không hợp lệ: %s", gateway_log)
        return _result_page(False, "Chữ ký không hợp lệ.")

    try:
        payment_id = int(params.get("vnp_TxnRef", ""))
    except ValueError:
        return _result_page(False, "Mã giao dịch không hợp lệ.")

    payment = await get_payment_by_id(db, payment_id)
    if payment is None:
        return _result_page(False, "Không tìm thấy đơn thanh toán.")

    # Chống xử lý lặp: người dùng bấm F5 trên trang kết quả sẽ gọi lại URL này.
    if payment.status == PAYMENT_PAID:
        return _result_page(True, "Đơn này đã được thanh toán trước đó.")

    if not vnpay.is_successful(params):
        await mark_payment_failed(db, payment, gateway_log)
        return _result_page(False, "Giao dịch không thành công hoặc đã bị huỷ.")

    # Số tiền VNPay trả về tính bằng đơn vị nhỏ nhất (x100). So lại với số tiền
    # đã ghi trong đơn — chữ ký hợp lệ vẫn không loại trừ được đơn bị sửa giá.
    expected_amount = int(payment.amount) * 100
    if params.get("vnp_Amount") != str(expected_amount):
        await mark_payment_failed(db, payment, gateway_log)
        logger.warning(
            "Số tiền không khớp cho đơn #%d: VNPay báo %s, đơn ghi %d",
            payment_id, params.get("vnp_Amount"), expected_amount,
        )
        return _result_page(False, "Số tiền giao dịch không khớp.")

    subscription = await get_subscription_by_id(db, payment.user_subscription_id)
    if subscription is None:
        return _result_page(False, "Không tìm thấy gói cước của đơn này.")

    plan = await get_plan_by_id(db, subscription.plan_id)
    plan_name = plan.name if plan else "Premium"

    await activate_subscription(
        db,
        payment=payment,
        subscription=subscription,
        transaction_no=params.get("vnp_TransactionNo"),
        gateway_log=gateway_log,
    )
    await create_notification(
        db,
        user_id=subscription.user_id,
        title=f"Kích hoạt gói {plan_name} thành công",
        body=f"Gói của bạn có hiệu lực tới {subscription.end_date:%d/%m/%Y}.",
        type_=TYPE_PAYMENT,
    )
    logger.info("Đơn #%d thanh toán thành công — kích hoạt gói %s", payment_id, plan_name)

    return _result_page(True, f"Đã kích hoạt gói {plan_name}.")


def _result_page(success: bool, message: str) -> HTMLResponse:
    """Trang kết quả hiển thị trong WebView của app.

    App không đọc trang này để biết kết quả — nó bắt chính URL `/vnpay/return`
    và tự gọi lại `/subscriptions/me`. Trang này chỉ để người dùng thấy có gì đó
    xảy ra, và để mở bằng trình duyệt thường vẫn có nghĩa.
    """
    color = "#22C55E" if success else "#EF4444"
    icon = "✓" if success else "✕"
    title = "Thanh toán thành công" if success else "Thanh toán thất bại"
    return HTMLResponse(f"""<!doctype html>
<html lang="vi"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title></head>
<body style="margin:0;display:flex;align-items:center;justify-content:center;
             height:100vh;background:#0B0C0D;color:#F5F5F5;
             font-family:system-ui,-apple-system,sans-serif;text-align:center">
  <div>
    <div style="font-size:56px;color:{color};line-height:1">{icon}</div>
    <h1 style="font-size:20px;margin:16px 0 8px">{title}</h1>
    <p style="color:#9A9A9E;font-size:14px;margin:0">{message}</p>
  </div>
</body></html>""")
