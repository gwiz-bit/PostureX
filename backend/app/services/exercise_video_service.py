"""Service lưu video hướng dẫn bài tập do admin upload — khác với
video_service.py (video tập luyện riêng tư của user): file ở đây được
serve công khai qua StaticFiles để mọi user xem được khi tập bài đó."""

import uuid
from pathlib import Path

import aiofiles
from fastapi import UploadFile

from app.core.config import settings

ALLOWED_EXTENSIONS = {".mp4", ".mov", ".avi", ".webm", ".mkv"}
MAX_FILE_SIZE_BYTES = 500 * 1024 * 1024  # 500 MB
PUBLIC_URL_PREFIX = "/media/exercise-videos"


class ExerciseVideoService:
    async def save(self, file: UploadFile) -> str:
        """Lưu file vào disk, trả về URL công khai (đường dẫn tương đối)."""
        original_name = file.filename or "unknown"
        suffix = Path(original_name).suffix.lower()

        if suffix not in ALLOWED_EXTENSIONS:
            raise ValueError(f"Định dạng file không được hỗ trợ: {suffix}")

        safe_name = f"{uuid.uuid4().hex}{suffix}"
        storage_path = settings.get_exercise_video_storage_path() / safe_name

        total_bytes = 0
        async with aiofiles.open(storage_path, "wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > MAX_FILE_SIZE_BYTES:
                    await out.close()
                    storage_path.unlink(missing_ok=True)
                    raise ValueError("File vượt quá kích thước tối đa 500 MB.")
                await out.write(chunk)

        return f"{PUBLIC_URL_PREFIX}/{safe_name}"

    def delete_by_url(self, url: str | None) -> None:
        """Xóa file vật lý tương ứng với 1 URL công khai đã lưu — no-op nếu
        url rỗng hoặc không khớp định dạng đang phục vụ (vd link ngoài)."""
        if not url or not url.startswith(f"{PUBLIC_URL_PREFIX}/"):
            return
        filename = url.removeprefix(f"{PUBLIC_URL_PREFIX}/")
        path = settings.get_exercise_video_storage_path() / filename
        if path.exists():
            path.unlink()


exercise_video_service = ExerciseVideoService()
