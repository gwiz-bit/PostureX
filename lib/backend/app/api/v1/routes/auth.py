"""Endpoints xác thực: đăng ký, xác thực OTP, và đăng nhập."""

from fastapi import APIRouter, Depends, HTTPException, status
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.core.security import create_access_token, verify_password
from app.crud.otp import create_otp, verify_otp
from app.crud.user import create_google_user, create_user, get_user_by_email
from app.schemas.auth import (
    GoogleLoginRequest,
    LoginRequest,
    MessageResponse,
    ResendOtpRequest,
    TokenResponse,
    VerifyOtpRequest,
)
from app.schemas.user import UserCreate, UserOut
from app.services.email_service import send_otp_email

router = APIRouter(prefix="/auth", tags=["auth"])


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
    except ValueError:
        raise HTTPException(status_code=401, detail="Google ID token không hợp lệ.")

    email = idinfo.get("email")
    if not email or not idinfo.get("email_verified"):
        raise HTTPException(status_code=401, detail="Tài khoản Google chưa xác thực email.")

    user = await get_user_by_email(db, email)
    if user is None:
        user = await create_google_user(db, email=email, full_name=idinfo.get("name"))
    elif not user.is_email_verified:
        user.is_email_verified = True
        await db.flush()

    token = create_access_token(user.id)
    return TokenResponse(access_token=token)


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
