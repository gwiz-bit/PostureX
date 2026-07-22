"""Endpoints xác thực: đăng ký, xác thực OTP, và đăng nhập."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.rate_limit import limiter
from app.core.security import create_access_token, hash_password, verify_password
from app.crud.otp import create_otp, verify_otp
from app.crud.password_reset import (
    create_reset_token,
    get_valid_reset_token,
    mark_reset_token_used,
)
from app.crud.user import create_google_user, create_user, get_user_by_email, get_user_by_id
from app.schemas.auth import (
    ForgotPasswordRequest,
    GoogleLoginRequest,
    LoginRequest,
    MessageResponse,
    ResendOtpRequest,
    ResetPasswordRequest,
    TokenResponse,
    VerifyOtpRequest,
)
from app.schemas.user import UserCreate, UserOut
from app.services.email_service import (
    send_otp_email,
    send_password_changed_email,
    send_reset_password_email,
)

router = APIRouter(prefix="/auth", tags=["auth"])
logger = logging.getLogger(__name__)

_GENERIC_FORGOT_PASSWORD_MESSAGE = (
    "Nếu email tồn tại trong hệ thống, chúng tôi đã gửi hướng dẫn đặt lại mật khẩu."
)


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(data: UserCreate, db: AsyncSession = Depends(get_db)) -> UserOut:
    """Đăng ký tài khoản mới — tạo user (chưa xác thực email) và gửi mã OTP.
    Tài khoản chỉ đăng nhập được sau khi xác thực OTP qua /auth/verify-otp."""
    existing = await get_user_by_email(db, data.email)
    if existing:
        raise HTTPException(status_code=400, detail="Email đã được sử dụng.")
    user = await create_user(db, data)

    otp = await create_otp(db, user)
    await db.flush()
    try:
        await send_otp_email(user.email, otp.code)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Không gửi được email OTP, thử lại sau. Chi tiết: {e}",
        )

    return UserOut.model_validate(user)


@router.post("/verify-otp", response_model=TokenResponse)
async def verify_otp_endpoint(
    data: VerifyOtpRequest, db: AsyncSession = Depends(get_db)
) -> TokenResponse:
    """Xác thực mã OTP để hoàn tất đăng ký — trả về JWT token để đăng nhập
    luôn sau khi xác thực thành công."""
    user = await get_user_by_email(db, data.email)
    if user is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản.")
    if user.is_email_verified:
        token = create_access_token(user.id)
        return TokenResponse(access_token=token)

    ok = await verify_otp(db, user, data.otp_code)
    if not ok:
        raise HTTPException(status_code=400, detail="Mã OTP không đúng hoặc đã hết hạn.")

    user.is_email_verified = True
    await db.flush()

    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


@router.post("/google", response_model=TokenResponse)
async def google_login(
    data: GoogleLoginRequest, db: AsyncSession = Depends(get_db)
) -> TokenResponse:
    """Đăng nhập/đăng ký bằng tài khoản Google đã có sẵn trên máy — xác
    thực id_token phía Google (không tin client), tự tạo tài khoản nếu
    email chưa tồn tại. Email do Google trả về luôn coi là đã xác thực nên
    bỏ qua bước OTP hoàn toàn."""
    if not settings.GOOGLE_CLIENT_ID:
        raise HTTPException(
            status_code=500, detail="Google Sign-In chưa được cấu hình trên server."
        )
    try:
        idinfo = google_id_token.verify_oauth2_token(
            data.id_token, google_requests.Request(), settings.GOOGLE_CLIENT_ID
        )
    except ValueError as e:
        logger.warning("Google ID token verification failed: %s", e)
        raise HTTPException(status_code=401, detail="Google ID token không hợp lệ.")

    email = idinfo.get("email")
    if not email or not idinfo.get("email_verified"):
        raise HTTPException(status_code=401, detail="Tài khoản Google chưa xác thực email.")

    user = await get_user_by_email(db, email)
    is_new_user = user is None
    if user is None:
        user = await create_google_user(db, email=email, full_name=idinfo.get("name"))
    elif not user.is_email_verified:
        user.is_email_verified = True
        await db.flush()

    token = create_access_token(user.id)
    return TokenResponse(access_token=token, is_new_user=is_new_user)


@router.post("/forgot-password", response_model=MessageResponse)
@limiter.limit("5/hour")
async def forgot_password(
    request: Request, data: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Yêu cầu đặt lại mật khẩu — LUÔN trả về cùng 1 thông báo chung
    chung, kể cả khi email không tồn tại trong hệ thống. Không tiết lộ
    email nào đã đăng ký hay chưa (chống user enumeration) — nếu trả lời
    khác nhau tùy email tồn tại hay không, kẻ tấn công có thể dò ra danh
    sách email thật của người dùng."""
    user = await get_user_by_email(db, data.email)
    if user is not None:
        raw_token = await create_reset_token(db, user)
        try:
            await send_reset_password_email(user.email, raw_token)
        except Exception as e:
            # Không để lộ qua response rằng việc gửi email thất bại — vẫn
            # trả về message chung, chỉ log lại để dev biết mà xử lý.
            logger.warning("Gửi email đặt lại mật khẩu thất bại cho %s: %s", user.email, e)

    return MessageResponse(message=_GENERIC_FORGOT_PASSWORD_MESSAGE)


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    data: ResetPasswordRequest, db: AsyncSession = Depends(get_db)
) -> MessageResponse:
    """Đặt mật khẩu mới bằng token nhận được qua email từ /forgot-password."""
    token = await get_valid_reset_token(db, data.token)
    if token is None:
        raise HTTPException(status_code=400, detail="Token không hợp lệ hoặc đã hết hạn.")

    user = await get_user_by_id(db, token.user_id)
    if user is None:
        raise HTTPException(status_code=400, detail="Token không hợp lệ hoặc đã hết hạn.")
    user.hashed_password = hash_password(data.new_password)
    await mark_reset_token_used(db, token)
    await db.flush()

    try:
        await send_password_changed_email(user.email)
    except Exception as e:
        logger.warning("Gửi email thông báo đổi mật khẩu thất bại cho %s: %s", user.email, e)

    return MessageResponse(message="Mật khẩu đã được đặt lại thành công.")


@router.post("/resend-otp", response_model=MessageResponse)
async def resend_otp(data: ResendOtpRequest, db: AsyncSession = Depends(get_db)) -> MessageResponse:
    """Gửi lại mã OTP mới (nếu email chưa được xác thực)."""
    user = await get_user_by_email(db, data.email)
    if user is None:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản.")
    if user.is_email_verified:
        return MessageResponse(message="Email đã được xác thực, bạn có thể đăng nhập.")

    otp = await create_otp(db, user)
    await db.flush()
    try:
        await send_otp_email(user.email, otp.code)
    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=f"Không gửi được email OTP, thử lại sau. Chi tiết: {e}",
        )
    return MessageResponse(message="Đã gửi lại mã OTP.")


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    """Đăng nhập, trả về JWT access token."""
    user = await get_user_by_email(db, data.email)
    if not user or not verify_password(data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Email hoặc mật khẩu không đúng.")
    if not user.is_email_verified:
        raise HTTPException(
            status_code=403,
            detail="Email chưa được xác thực. Vui lòng nhập mã OTP đã gửi tới email.",
        )
    token = create_access_token(user.id)
    return TokenResponse(access_token=token)
