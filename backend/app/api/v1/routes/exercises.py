"""Endpoint công khai: danh sách bài tập đang active trong thư viện."""

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.crud import exercise as exercise_crud
from app.ml.analyzers.registry import supports_analysis
from app.schemas.exercise import ExerciseOut

router = APIRouter(tags=["exercises"])


@router.get("/exercises", response_model=list[ExerciseOut])
async def list_exercises(db: AsyncSession = Depends(get_db)) -> list[ExerciseOut]:
    """Thư viện bài tập đang mở (is_active=True) — dùng cho màn Exercises của app.

    Trả nguyên danh sách, không phân trang: client lọc theo nhóm cơ và tìm
    kiếm theo tên ngay trên máy, nên cần đủ dữ liệu một lần. Với ~400 bài
    response khoảng 120 KB — chấp nhận được, và đổi lại thanh tìm kiếm phản
    hồi tức thì thay vì gọi mạng theo từng ký tự.

    Mỗi bài kèm hai trường không nằm trong bảng Exercises:

    - `muscle_groups` — để client dựng thanh lọc 16 nhóm cơ và hiện nhãn.
    - `supports_analysis` — bài có analyzer tư thế riêng hay không. Thư viện
      hơn 400 bài nhưng chỉ 16 analyzer; thiếu cờ này thì client cho người dùng
      bấm "Phân tích tư thế" ở bài tập cổ rồi nghe app đọc feedback squat.
    """
    exercises = await exercise_crud.get_active_exercises(db)
    groups = await exercise_crud.get_muscle_groups_by_exercise(db, [e.id for e in exercises])

    out: list[ExerciseOut] = []
    for e in exercises:
        item = ExerciseOut.model_validate(e)
        item.muscle_groups = groups.get(e.id, [])
        item.supports_analysis = supports_analysis(e.name)
        out.append(item)
    return out
