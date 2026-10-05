"""Xoá tài khoản qua web, không cần cài/mở app (trang /delete-account).

Dành cho người đã gỡ app hoặc không có thiết bị — Google Play bắt buộc phải có
đường này bên cạnh nút xoá trong app. Quyền sở hữu được chứng minh bằng mã gửi
tới đúng email của tài khoản (cũng đúng với tài khoản đăng ký bằng Google, vốn
không có mật khẩu). Không có bước chờ duyệt thủ công: xác nhận xong là xoá ngay.
"""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.rate_limit import limiter
from app.crud.account_deletion import CODE_EXPIRE_MINUTES, create_request, verify_code
from app.crud.user import get_user_by_email
from app.schemas.auth import AccountDeletionConfirmIn, AccountDeletionRequestIn, MessageResponse
from app.services.account_deletion import delete_user_account
from app.services.email_service import send_account_deletion_email

router = APIRouter(prefix="/account-deletion", tags=["account-deletion"])
logger = logging.getLogger(__name__)

# Luôn trả đúng câu này dù email có tồn tại hay không — không để kẻ lạ dò ra ai
# đã đăng ký (cùng nguyên tắc với /auth/forgot-password).
_GENERIC_REQUEST_MESSAGE = (
    "Nếu email này có tài khoản Posture X, chúng tôi đã gửi một mã xác nhận tới đó. "
    f"Mã có hiệu lực trong {CODE_EXPIRE_MINUTES} phút."
)
_INVALID_CODE_MESSAGE = "Mã xác nhận không đúng hoặc đã hết hạn."


@router.post("/request", response_model=MessageResponse)
@limiter.limit("5/hour")
async def request_account_deletion(
    request: Request, data: AccountDeletionRequestIn, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Bước 1: gửi mã xác nhận tới email."""
    user = await get_user_by_email(db, data.email)
    # Tài khoản admin không xoá được qua đường công khai này.
    if user is not None and not user.is_admin:
        code = await create_request(db, user)
        if code is not None:
            try:
                await send_account_deletion_email(user.email, code, CODE_EXPIRE_MINUTES)
            except Exception as e:  # không để lộ qua response là gửi thất bại
                logger.warning("Gửi mã xoá tài khoản thất bại cho %s: %s", user.email, e)
    return MessageResponse(message=_GENERIC_REQUEST_MESSAGE)


@router.post("/confirm", response_model=MessageResponse)
@limiter.limit("10/hour")
async def confirm_account_deletion(
    request: Request, data: AccountDeletionConfirmIn, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Bước 2: nhập mã — đúng thì xoá ngay, vĩnh viễn."""
    user = await get_user_by_email(db, data.email)
    if user is None or user.is_admin or not await verify_code(db, user, data.code):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=_INVALID_CODE_MESSAGE)

    await delete_user_account(db, user)
    return MessageResponse(message="Tài khoản và dữ liệu của bạn đã được xoá vĩnh viễn.")
