"""Service xử lý upload, lưu video và tạo metadata trong DB."""

import uuid
from pathlib import Path

import aiofiles
from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.video import Video


class VideoService:
    """Lưu file video và tạo bản ghi metadata bất đồng bộ."""

    ALLOWED_EXTENSIONS = {".mp4", ".mov", ".avi", ".webm", ".mkv"}
    MAX_FILE_SIZE_BYTES = 500 * 1024 * 1024  # 500 MB

    async def save(
        self,
        file: UploadFile,
        user_id: int,
        exercise: str,
        db: AsyncSession,
    ) -> Video:
        """
        Nhận UploadFile, lưu vào disk, tạo bản ghi Video trong database.

        Trả về Video object đã được thêm vào session (chưa commit).
        """
        original_name = file.filename or "unknown"
        suffix = Path(original_name).suffix.lower()

        if suffix not in self.ALLOWED_EXTENSIONS:
            raise ValueError(f"Định dạng file không được hỗ trợ: {suffix}")

        # Tên file an toàn theo UUID để tránh trùng lặp và path traversal
        safe_name = f"{uuid.uuid4().hex}{suffix}"
        storage_path = settings.get_video_storage_path() / safe_name

        # Ghi file bất đồng bộ theo từng chunk 1MB
        total_bytes = 0
        async with aiofiles.open(storage_path, "wb") as out:
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                total_bytes += len(chunk)
                if total_bytes > self.MAX_FILE_SIZE_BYTES:
                    await out.close()
                    storage_path.unlink(missing_ok=True)
                    raise ValueError("File vượt quá kích thước tối đa 500 MB.")
                await out.write(chunk)

        video = Video(
            user_id=user_id,
            exercise=exercise.lower().strip(),
            file_path=str(storage_path),
            original_filename=original_name,
        )
        db.add(video)
        return video

    async def delete_file(self, video: Video) -> None:
        """Xóa file vật lý khỏi disk."""
        path = Path(video.file_path)
        if path.exists():
            path.unlink()


video_service = VideoService()
