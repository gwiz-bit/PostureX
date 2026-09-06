"""Endpoints upload và truy vấn video buổi tập."""

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud.video import get_video_by_id, get_videos_by_user
from app.models.user import User
from app.schemas.video import VideoOut
from app.services.video_analysis_service import analyze_and_store
from app.services.video_service import video_service
from app.utils.deps import get_current_user

router = APIRouter(prefix="/videos", tags=["videos"])


@router.post("/upload", response_model=VideoOut, status_code=status.HTTP_201_CREATED)
async def upload_video(
    background_tasks: BackgroundTasks,
    file: UploadFile,
    exercise: str = "squat",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> VideoOut:
    """
    Upload video buổi tập.

    - **file**: file video (mp4, mov, avi, webm, mkv)
    - **exercise**: tên bài tập (mặc định: squat)

    Response trả về NGAY sau khi lưu file xong (`total_reps`/`accuracy_score`/
    `analysis_summary` còn ở giá trị mặc định) — phân tích tư thế chạy NGẦM
    sau đó qua `BackgroundTasks`, vì một video vài chục giây có thể tốn hàng
    chục giây pose estimation, bắt client chờ hết lúc đó mới có phản hồi là
    trải nghiệm tệ. Client cần tự gọi lại `GET /videos/{id}` sau vài giây để
    lấy kết quả phân tích.
    """
    try:
        video = await video_service.save(
            file=file,
            user_id=current_user.id,
            exercise=exercise,
            db=db,
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))

    # Commit ngay để lấy `video.id` (tự tăng, chỉ có sau khi flush) truyền
    # cho tác vụ nền — `expire_on_commit=False` (xem core/database.py) nên
    # không cần refresh lại, các thuộc tính khác của `video` vẫn dùng được
    # bình thường. `get_db` còn tự commit một lần nữa sau khi hàm này trả
    # về; gọi thêm ở đây không phải lỗi, chỉ là không còn gì mới để ghi.
    await db.commit()
    background_tasks.add_task(analyze_and_store, video.id)
    return VideoOut.model_validate(video)


@router.get("", response_model=list[VideoOut])
async def list_videos(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[VideoOut]:
    """Lấy danh sách tất cả video của user hiện tại."""
    videos = await get_videos_by_user(db, current_user.id)
    return [VideoOut.model_validate(v) for v in videos]


@router.get("/{video_id}", response_model=VideoOut)
async def get_video(
    video_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> VideoOut:
    """Lấy chi tiết một video theo ID."""
    video = await get_video_by_id(db, video_id, current_user.id)
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy video.")
    return VideoOut.model_validate(video)
