"""Gửi push notification qua Firebase Cloud Messaging (FCM HTTP v1).

Gọi thẳng REST API bằng `google-auth` + `httpx` — **không** kéo thêm
`firebase-admin`. Hai thư viện đó repo đã có sẵn (google-auth dùng cho Google
Sign-In), còn firebase-admin sẽ thêm một cây phụ thuộc nặng chỉ để làm đúng việc
này.

**Chưa cấu hình thì im lặng bỏ qua** (giống `vnpay_configured`): thiếu file khoá
Firebase, hàm chỉ ghi log rồi thoát. Nhờ vậy backend chạy được trên máy chưa ai
lập project Firebase, và thông báo trong app vẫn hoạt động bình thường — push
chỉ là lớp phủ thêm.

Cần gì để bật:
  1. Firebase Console → Project settings → Service accounts → Generate new
     private key → tải file JSON về.
  2. Đặt vào `lib/backend/` (đã có .gitignore chặn — **đừng commit file này**).
  3. Điền vào `.env`:
        FCM_CREDENTIALS_FILE=firebase-service-account.json
        FCM_PROJECT_ID=ten-project-firebase
"""

import logging

import httpx
from google.auth.transport.requests import Request as GoogleRequest
from google.oauth2 import service_account

from app.core.config import settings

logger = logging.getLogger(__name__)

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
FCM_ENDPOINT = "https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

# FCM trả các mã này khi token không còn dùng được (app bị gỡ, token hết hạn).
# Gặp là phải xoá token khỏi DB, đừng thử lại.
DEAD_TOKEN_STATUSES = {"UNREGISTERED", "INVALID_ARGUMENT", "NOT_FOUND"}

_credentials: service_account.Credentials | None = None


def _get_access_token() -> str | None:
    """Lấy OAuth access token cho FCM. Tự làm mới khi hết hạn.

    Giữ credentials ở biến module: `google-auth` cache token bên trong và chỉ gọi
    lại Google khi sắp hết hạn — tạo mới mỗi lần gửi là tự đấm mình bằng một
    round-trip mạng thừa.
    """
    global _credentials

    if not settings.fcm_configured:
        return None

    if _credentials is None:
        _credentials = service_account.Credentials.from_service_account_file(
            settings.FCM_CREDENTIALS_FILE, scopes=[FCM_SCOPE]
        )

    if not _credentials.valid:
        _credentials.refresh(GoogleRequest())

    return _credentials.token


async def send_push(
    tokens: list[str],
    title: str,
    body: str | None = None,
    data: dict[str, str] | None = None,
) -> list[str]:
    """Đẩy một thông báo tới danh sách thiết bị.

    Trả về **danh sách token đã chết** để nơi gọi xoá khỏi DB. Trả rỗng nếu chưa
    cấu hình FCM hoặc không có thiết bị nào.

    Lỗi mạng/lỗi FCM **không được ném ra ngoài**: push hỏng thì thông báo trong
    app vẫn phải lưu bình thường. Không ai muốn mất buổi tập chỉ vì Firebase sập.
    """
    if not tokens:
        return []

    access_token = _get_access_token()
    if access_token is None:
        logger.debug("Bỏ qua push: chưa cấu hình FCM.")
        return []

    url = FCM_ENDPOINT.format(project_id=settings.FCM_PROJECT_ID)
    headers = {"Authorization": f"Bearer {access_token}"}
    dead: list[str] = []

    async with httpx.AsyncClient(timeout=10) as client:
        for token in tokens:
            message = {
                "message": {
                    "token": token,
                    "notification": {"title": title, "body": body or ""},
                    "data": data or {},
                }
            }
            try:
                response = await client.post(url, headers=headers, json=message)
            except httpx.HTTPError as exc:
                logger.warning("Gửi push thất bại (lỗi mạng): %s", exc)
                continue

            if response.status_code == 200:
                continue

            status = _error_status(response)
            if status in DEAD_TOKEN_STATUSES:
                dead.append(token)
            else:
                logger.warning(
                    "FCM từ chối (%d): %s", response.status_code, response.text[:200]
                )

    return dead


def _error_status(response: httpx.Response) -> str | None:
    """Bóc mã lỗi FCM khỏi body. Body không phải JSON thì trả None."""
    try:
        return response.json().get("error", {}).get("status")
    except ValueError:
        return None
