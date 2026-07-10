"""Pydantic schemas cho xác thực."""

from pydantic import BaseModel, EmailStr


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
