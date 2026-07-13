"""Cau hinh ung dung doc tu file .env."""

import urllib.parse
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # App
    APP_NAME: str = "Posture X"
    DEBUG: bool = False

    # MySQL connection parts
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "posturex"
    DB_USER: str = "root"
    DB_PASSWORD: str = ""

    # JWT
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Luu tru video
    VIDEO_STORAGE_PATH: str = "storage/videos"

    # CORS
    ALLOWED_ORIGINS: list[str] = ["*"]

    # SMTP — gui email OTP xac thuc dang ky
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_NAME: str = "Posture X"

    # OTP
    OTP_EXPIRE_MINUTES: int = 10

    # Dat lai mat khau
    RESET_TOKEN_EXPIRE_MINUTES: int = 30

    # Google Sign-In — "Web application" OAuth client ID from Google Cloud
    # Console (NOT the Android client ID). This is the expected `aud` claim
    # when verifying ID tokens from the Flutter app's google_sign_in flow.
    GOOGLE_CLIENT_ID: str = ""

    def get_database_url(self) -> str:
        """Tao async connection URL cho MySQL qua aiomysql."""
        user = urllib.parse.quote_plus(self.DB_USER)
        password = urllib.parse.quote_plus(self.DB_PASSWORD)
        return (
            f"mysql+aiomysql://{user}:{password}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    def get_video_storage_path(self) -> Path:
        """Tra ve duong dan thu muc luu video dang Path."""
        path = Path(self.VIDEO_STORAGE_PATH)
        path.mkdir(parents=True, exist_ok=True)
        return path


settings = Settings()
