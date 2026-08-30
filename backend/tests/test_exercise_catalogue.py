"""Test danh mục bài tập gửi kèm prompt sinh lịch tập AI.

Thư viện thật có 417 bài. Gửi nguyên cả danh sách vào prompt tốn ~2.400 token
input mỗi lần bấm "Personalize with AI", nên `_build_exercise_catalogue` cắt
còn tối đa 8 bài mỗi nhóm cơ. Các test dưới đây khoá lại hai tính chất dễ mất
nhất khi ai đó chỉnh lại phần cắt: mọi nhóm cơ đều phải còn mặt, và bài app
chấm được kỹ thuật phải được ưu tiên.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.routes.coach import _MAX_EXERCISES_PER_MUSCLE_GROUP, _build_exercise_catalogue
from app.models.exercise import Exercise
from app.models.muscle_group import ExerciseMuscleGroup, MuscleGroup


async def _seed(db: AsyncSession, group_name: str, exercise_names: list[str]) -> None:
    group = MuscleGroup(name=group_name)
    db.add(group)
    await db.flush()
    for name in exercise_names:
        exercise = Exercise(name=name, is_active=True)
        db.add(exercise)
        await db.flush()
        db.add(
            ExerciseMuscleGroup(
                exercise_id=exercise.id, muscle_group_id=group.id, is_primary=True
            )
        )
    await db.flush()


@pytest.mark.asyncio
async def test_cat_toi_da_n_bai_moi_nhom(db_session: AsyncSession) -> None:
    await _seed(db_session, "Biceps", [f"Curl Variation {i}" for i in range(20)])

    catalogue = await _build_exercise_catalogue(db_session)

    listed = catalogue.split(": ", 1)[1].split(", ")
    assert len(listed) == _MAX_EXERCISES_PER_MUSCLE_GROUP


@pytest.mark.asyncio
async def test_moi_nhom_co_deu_con_mat(db_session: AsyncSession) -> None:
    """Cắt theo từng nhóm chứ không cắt thẳng danh sách chung.

    Cắt thẳng thì nhóm đứng cuối bảng chữ cái biến mất hẳn và lịch tập AI sinh
    ra sẽ lệch — không bao giờ có bài bắp chân hay cẳng tay.
    """
    await _seed(db_session, "Back", [f"Row Variation {i}" for i in range(15)])
    await _seed(db_session, "Calves", ["Standing Calf Raise"])
    await _seed(db_session, "tibialis", ["Tibialis Raise"])

    catalogue = await _build_exercise_catalogue(db_session)

    assert "- Back:" in catalogue
    assert "Standing Calf Raise" in catalogue
    assert "Tibialis Raise" in catalogue


@pytest.mark.asyncio
async def test_bai_cham_duoc_ky_thuat_duoc_danh_dau_va_xep_truoc(
    db_session: AsyncSession,
) -> None:
    """`*` = app chấm được tư thế. Xếp trước để khi cắt còn 8 bài thì phần bị
    cắt là các bài chỉ xem được video, không phải ngược lại."""
    await _seed(
        db_session,
        "Chest",
        ["Aaa Chest Fly", "Barbell Bench Press"],  # "Aaa" đứng trước theo bảng chữ cái
    )

    catalogue = await _build_exercise_catalogue(db_session)

    listed = catalogue.split(": ", 1)[1].split(", ")
    assert listed[0] == "*Barbell Bench Press"
    assert listed[1] == "Aaa Chest Fly"


@pytest.mark.asyncio
async def test_bai_chua_gan_nhom_co_van_xuat_hien(db_session: AsyncSession) -> None:
    """Không gán nhóm cơ thì rơi vào "Khác" — nếu bỏ qua, bài đó âm thầm biến
    mất khỏi mọi lịch tập AI sinh ra mà không ai biết."""
    db_session.add(Exercise(name="Bài Tập Chưa Phân Loại", is_active=True))
    await db_session.flush()

    catalogue = await _build_exercise_catalogue(db_session)

    assert "Khác" in catalogue
    assert "Bài Tập Chưa Phân Loại" in catalogue


@pytest.mark.asyncio
async def test_thu_vien_rong(db_session: AsyncSession) -> None:
    assert await _build_exercise_catalogue(db_session) == "(chưa có dữ liệu)"
