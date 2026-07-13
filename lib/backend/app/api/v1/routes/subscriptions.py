"""Endpoints gói cước & thanh toán MoMo."""

import logging
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
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
from app.services import momo
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
    """Tạo đơn chờ thanh toán và trả về URL thanh toán MoMo."""
    if not settings.momo_configured:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Chưa cấu hình MoMo trên server.",
        )

    plan = await get_plan_by_id(db, data.plan_id)
    if plan is None or not plan.is_active:
        raise HTTPException(status_code=404, detail="Không tìm thấy gói cước.")

    # Gói miễn phí không đi qua cổng thanh toán — chặn ở đây thay vì tạo ra một
    # đơn 0đ mà MoMo sẽ từ chối.
    if plan.price_monthly <= 0:
        raise HTTPException(status_code=400, detail="Gói miễn phí không cần thanh toán.")

    amount = int(plan.price_monthly)
    if not momo.MOMO_MIN_AMOUNT <= amount <= momo.MOMO_MAX_AMOUNT:
        raise HTTPException(
            status_code=400,
            detail=f"MoMo chỉ nhận đơn từ {momo.MOMO_MIN_AMOUNT:,}đ "
            f"đến {momo.MOMO_MAX_AMOUNT:,}đ.",
        )

    subscription, payment = await create_pending_order(db, current_user.id, plan)

    result = await momo.create_payment(
        amount=amount,
        order_id=_order_id(payment.id),
        order_info=f"Thanh toan goi {plan.name}",
        redirect_url=settings.MOMO_REDIRECT_URL,
        ipn_url=settings.MOMO_IPN_URL,
    )

    pay_url = result.get("payUrl")
    if not momo.is_successful(result.get("resultCode")) or not pay_url:
        # Đơn đã ghi vào DB nhưng MoMo từ chối → đánh dấu hỏng ngay, đừng để lại
        # một dòng Pending treo mãi không ai biết vì sao.
        await mark_payment_failed(db, payment, str(result))
        logger.warning("MoMo từ chối tạo đơn #%d: %s", payment.id, result.get("message"))
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"MoMo từ chối tạo đơn: {result.get('message', 'không rõ lý do')}",
        )

    logger.info(
        "Tạo đơn thanh toán #%d cho user %d — gói %s", payment.id, current_user.id, plan.name
    )
    return CheckoutOut(payment_id=payment.id, pay_url=pay_url)


ORDER_PREFIX = "PX"


def _order_id(payment_id: int) -> str:
    """orderId gửi MoMo. Phải duy nhất với mỗi partner → dùng PaymentId."""
    return f"{ORDER_PREFIX}{payment_id}"


def _payment_id_from(order_id: str) -> int | None:
    if not order_id.startswith(ORDER_PREFIX):
        return None
    try:
        return int(order_id[len(ORDER_PREFIX):])
    except ValueError:
        return None


@router.get("/payments/momo/return", response_class=HTMLResponse)
async def momo_return(request: Request, db: AsyncSession = Depends(get_db)) -> HTMLResponse:
    """MoMo redirect trình duyệt người dùng về đây sau khi thanh toán.

    **Không có auth** — MoMo không mang theo token. Danh tính đơn lấy từ `orderId`.

    ⚠️ **KHÔNG tin tham số trên URL này.** Người dùng có thể tự sửa URL trong
    WebView và tự "báo thành công". Thay vào đó, backend **hỏi thẳng MoMo** qua
    API `/query` xem đơn đó thật sự đã trả tiền chưa — MoMo mới là nguồn sự thật.

    Đây cũng là lý do đổi từ VNPay sang MoMo: VNPay không có API tra cứu, muốn
    chắc chắn thì bắt buộc phải có IPN (cần URL công khai, localhost không làm
    được). MoMo thì xác minh được ngay cả khi chạy localhost.
    """
    order_id = request.query_params.get("orderId", "")
    return await _settle(db, order_id, source="redirect")


@router.post("/payments/momo/ipn", status_code=status.HTTP_204_NO_CONTENT)
async def momo_ipn(request: Request, db: AsyncSession = Depends(get_db)) -> Response:
    """MoMo gọi server-to-server khi thanh toán xong (kênh đáng tin nhất).

    Cần **URL công khai** nên chạy localhost thì MoMo không gọi tới được — luồng
    chính hiện dựa vào `/return` + `/query`. Route này để sẵn cho lúc deploy thật:
    nó bắt được cả trường hợp người dùng **trả tiền xong rồi tắt app ngay**, khi
    đó `/return` không bao giờ chạy.

    Xác minh bằng chữ ký HMAC — không có secretKey thì không giả mạo được.
    MoMo chờ HTTP 204; trả mã khác nó sẽ gọi lại.
    """
    payload = await request.json()

    if not momo.verify_ipn_signature(payload):
        logger.warning("IPN MoMo có chữ ký không hợp lệ: %s", payload.get("orderId"))
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    await _settle(db, payload.get("orderId", ""), source="ipn")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


async def _settle(db: AsyncSession, order_id: str, source: str) -> HTMLResponse:
    """Chốt một đơn: hỏi MoMo trạng thái thật rồi kích hoạt gói (hoặc đánh hỏng).

    Dùng chung cho cả `/return` và `/ipn` — hai kênh có thể cùng bắn về một đơn,
    nên hàm này phải **idempotent**: gọi lại lần hai không được cộng thêm ngày.
    """
    payment_id = _payment_id_from(order_id)
    if payment_id is None:
        return _result_page(False, "Mã giao dịch không hợp lệ.")

    payment = await get_payment_by_id(db, payment_id)
    if payment is None:
        return _result_page(False, "Không tìm thấy đơn thanh toán.")

    # Chống xử lý lặp: người dùng bấm F5, hoặc IPN về sau khi /return đã chốt.
    if payment.status == PAYMENT_PAID:
        return _result_page(True, "Đơn này đã được thanh toán trước đó.")

    # NGUỒN SỰ THẬT: hỏi MoMo, không đọc tham số người dùng gửi lên.
    result = await momo.query_payment(order_id)
    gateway_log = str(result)
    result_code = result.get("resultCode")

    # Đang chờ người dùng xác nhận (vd: quay về app giữa lúc quét QR). **Không
    # được đánh hỏng** — họ vẫn có thể trả tiền xong, và IPN sẽ chốt sau.
    if momo.is_pending(result_code):
        logger.info("Đơn #%d còn đang chờ thanh toán — nguồn: %s", payment_id, source)
        return _result_page(
            False, "Bạn chưa hoàn tất thanh toán. Đơn vẫn còn hiệu lực, có thể trả tiếp."
        )

    if not momo.is_successful(result_code):
        await mark_payment_failed(db, payment, gateway_log)
        logger.info(
            "Đơn #%d thất bại (%s) — nguồn: %s",
            payment_id, result.get("message"), source,
        )
        return _result_page(False, "Giao dịch không thành công hoặc đã bị huỷ.")

    # Chữ ký hợp lệ vẫn không loại trừ được đơn bị sửa giá → so lại số tiền.
    if int(result.get("amount", 0)) != int(payment.amount):
        await mark_payment_failed(db, payment, gateway_log)
        logger.warning(
            "Số tiền không khớp cho đơn #%d: MoMo báo %s, đơn ghi %d",
            payment_id, result.get("amount"), int(payment.amount),
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
        transaction_no=str(result.get("transId", "")),
        gateway_log=gateway_log,
    )
    await create_notification(
        db,
        user_id=subscription.user_id,
        title=f"Kích hoạt gói {plan_name} thành công",
        body=f"Gói của bạn có hiệu lực tới {subscription.end_date:%d/%m/%Y}.",
        type_=TYPE_PAYMENT,
    )
    logger.info(
        "Đơn #%d thanh toán thành công — kích hoạt gói %s (nguồn: %s)",
        payment_id, plan_name, source,
    )
    return _result_page(True, f"Đã kích hoạt gói {plan_name}.")


def _result_page(success: bool, message: str) -> HTMLResponse:
    """Trang kết quả hiển thị trong WebView của app.

    App không đọc trang này để biết kết quả — nó bắt chính URL `/momo/return`
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
