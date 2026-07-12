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

    # Google Sign-In — "Web application" OAuth client ID from Google Cloud
    # Console (NOT the Android client ID). This is the expected `aud` claim
    # when verifying ID tokens from the Flutter app's google_sign_in flow.
    GOOGLE_CLIENT_ID: str = ""

    # VNPay — lay TmnCode/HashSecret o https://sandbox.vnpayment.vn
    VNPAY_TMN_CODE: str = ""
    VNPAY_HASH_SECRET: str = ""
    VNPAY_PAY_URL: str = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"
    # VNPay redirect trinh duyet cua nguoi dung ve day sau khi thanh toan.
    # Tren emulator, WebView cua app goi duoc 10.0.2.2 (= localhost cua may host).
    # Doi sang IP LAN neu test tren dien thoai that.
    VNPAY_RETURN_URL: str = "http://10.0.2.2:9000/api/v1/payments/vnpay/return"

    # Firebase Cloud Messaging — push notification (BE-13).
    # Lay file khoa: Firebase Console > Project settings > Service accounts >
    # Generate new private key. KHONG commit file nay.
    FCM_CREDENTIALS_FILE: str = ""
    FCM_PROJECT_ID: str = ""

    # Job dinh ky (BE-13). Gio tinh theo mui gio Viet Nam.
    REMINDERS_ENABLED: bool = True
    # Nhac nghi giai lao — cac moc trong gio lam viec. Doi thanh "9,11,14,16"
    # trong .env neu muon nhac day hon.
    BREAK_REMINDER_HOURS: str = "10,15"
    # Tong ket hang ngay — 20h toi, luc nguoi dung da tap xong.
    DAILY_SUMMARY_HOUR: int = 20

    @property
    def vnpay_configured(self) -> bool:
        """False khi chua dien TmnCode/HashSecret — route checkout se bao 503
        thay vi dung URL rac roi de VNPay tu choi voi loi kho hieu."""
        return bool(self.VNPAY_TMN_CODE and self.VNPAY_HASH_SECRET)

    @property
    def fcm_configured(self) -> bool:
        """False khi chua co khoa Firebase — push bi bo qua trong im lang.

        Co y KHONG kiem tra file co ton tai that khong: kiem tra I/O trong mot
        property se chay lai moi lan gui push. Thieu file that thi
        service_account.Credentials se nem loi ro rang ngay lan gui dau tien.
        """
        return bool(self.FCM_CREDENTIALS_FILE and self.FCM_PROJECT_ID)

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
