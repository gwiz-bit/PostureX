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
    DB_NAME: str = "poturex123"
    DB_USER: str = "root"
    DB_PASSWORD: str = "123456"

    # JWT
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Luu tru video
    VIDEO_STORAGE_PATH: str = "storage/videos"

    # Luu tru video huong dan bai tap (admin upload, public, khac voi
    # storage/videos la video tap luyen rieng tu cua user)
    EXERCISE_VIDEO_STORAGE_PATH: str = "storage/exercise_videos"

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

    # AI Coach chat — Gemini API key from aistudio.google.com/apikey.
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-flash-latest"

    # MoMo (AIO v2) — cong thanh toan dang dung.
    #
    # Gia tri mac dinh la BO KHOA SANDBOX CONG KHAI cua MoMo, lay tu repo mau
    # chinh thuc github.com/momo-wallet/payment. KHONG phai bi mat, va KHONG
    # tieu duoc tien that - nho vay ai clone repo ve cung chay duoc ngay, khong
    # phai dang ky merchant. Len production thi phai thay bang khoa that va dua
    # vao .env (dung commit).
    MOMO_PARTNER_CODE: str = "MOMO"
    MOMO_ACCESS_KEY: str = "F8BBA842ECF85"
    MOMO_SECRET_KEY: str = "K951B6PE1waDMi640xX08PD3vg6EkVlz"
    MOMO_CREATE_URL: str = "https://test-payment.momo.vn/v2/gateway/api/create"
    MOMO_QUERY_URL: str = "https://test-payment.momo.vn/v2/gateway/api/query"
    # MoMo redirect trinh duyet nguoi dung ve day sau khi thanh toan.
    # Tren emulator, WebView goi duoc 10.0.2.2 (= localhost cua may host).
    # Doi sang IP LAN neu test tren dien thoai that.
    MOMO_REDIRECT_URL: str = "http://10.0.2.2:9000/api/v1/payments/momo/return"
    # IPN: MoMo goi server-to-server. Can URL CONG KHAI, chay localhost thi MoMo
    # khong goi toi duoc - vi vay luong chinh dua vao /query (hoi thang MoMo).
    MOMO_IPN_URL: str = "http://10.0.2.2:9000/api/v1/payments/momo/ipn"

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
    def momo_configured(self) -> bool:
        """False khi thieu khoa MoMo — route checkout bao 503 thay vi gui request
        rac roi de MoMo tu choi voi loi kho hieu."""
        return bool(self.MOMO_PARTNER_CODE and self.MOMO_ACCESS_KEY and self.MOMO_SECRET_KEY)

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

    def get_exercise_video_storage_path(self) -> Path:
        """Tra ve duong dan thu muc luu video huong dan bai tap."""
        path = Path(self.EXERCISE_VIDEO_STORAGE_PATH)
        path.mkdir(parents=True, exist_ok=True)
        return path


settings = Settings()
