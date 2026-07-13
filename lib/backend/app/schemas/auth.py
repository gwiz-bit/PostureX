"""Pydantic schemas cho xác thực."""

from pydantic import BaseModel, EmailStr, field_validator, model_validator

from app.schemas.validators import validate_password_strength


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class VerifyOtpRequest(BaseModel):
    email: EmailStr
    otp_code: str


class ResendOtpRequest(BaseModel):
    email: EmailStr


class GoogleLoginRequest(BaseModel):
    """`idToken` từ `GoogleSignInAccount.authentication` phía Flutter —
    xác thực phía server qua google-auth, không tin cậy client."""

    id_token: str


class MessageResponse(BaseModel):
    message: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str
    confirm_password: str

    @field_validator("new_password")
    @classmethod
    def _validate_strength(cls, v: str) -> str:
        """Yêu cầu mạnh hơn mật khẩu đăng ký thông thường (chỉ >= 6 ký tự)
        vì đây là bước khôi phục quyền truy cập tài khoản qua email — nơi
        dễ bị dò/đoán mật khẩu yếu hơn nếu hộp thư bị lộ."""
        return validate_password_strength(v)

    @model_validator(mode="after")
    def _validate_confirm(self) -> "ResetPasswordRequest":
        if self.new_password != self.confirm_password:
            raise ValueError("Mật khẩu xác nhận không khớp.")
        return self
