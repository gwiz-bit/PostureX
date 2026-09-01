"""Test ngưỡng góc riêng theo từng bài tập (`ExercisePostureRules`).

Chỉ có 9 analyzer cho 106 bài, nên mọi biến thể cùng họ vốn bị chấm bằng đúng
một bộ ngưỡng — `Seal Row` nằm sấp dùng chung ngưỡng lưng với `Barbell Bent
Over Row` cúi 45°. Cơ chế này cho phép ghi đè từng con số cho từng bài mà
không phải viết analyzer mới.

Hai tính chất quan trọng nhất được khoá ở đây:
  1. Không có ngưỡng riêng thì phải giữ NGUYÊN hành vi cũ — nếu không, bật cơ
     chế lên là 106 bài đang chạy đổi kết quả cùng lúc.
  2. Có ngưỡng riêng thì phải thực sự đổi cách chấm, kể cả ngưỡng đếm rep.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.analyzers.row import BACK_STRAIGHT_MIN, RowAnalyzer
from app.ml.analyzers.squat import KNEE_DEPTH_THRESHOLD, SquatAnalyzer
from app.ml.analyzers.thresholds import VALUE_COLUMN, load_thresholds
from app.models.exercise import Exercise
from app.models.posture_rule import ExercisePostureRule
from tests.pose_builders import arm_pose, squat_pose
from tests.test_analyzers import rep_sequence


async def _add_rule(db: AsyncSession, exercise_name: str, key: str, value: float) -> None:
    exercise = Exercise(name=exercise_name, is_active=True)
    db.add(exercise)
    await db.flush()
    rule = ExercisePostureRule(
        exercise_id=exercise.id,
        rule_name=key,
        joint_a="Shoulder",
        joint_b="Hip",
        joint_c="Knee",
    )
    setattr(rule, VALUE_COLUMN[key], value)
    db.add(rule)
    await db.flush()


# ─────────────────────────────────────────────────────────────────────
# Đọc ngưỡng từ DB
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_bai_chua_co_nguong_rieng_tra_rong(db_session: AsyncSession) -> None:
    """Đây là điều kiện để bật cơ chế mà không đổi hành vi 106 bài đang chạy."""
    db_session.add(Exercise(name="Barbell Bent Over Row", is_active=True))
    await db_session.flush()

    assert await load_thresholds(db_session, "Barbell Bent Over Row") == {}


@pytest.mark.asyncio
async def test_bai_khong_ton_tai_tra_rong(db_session: AsyncSession) -> None:
    assert await load_thresholds(db_session, "Bài Không Có Thật") == {}


@pytest.mark.asyncio
async def test_doc_dung_nguong_da_nhap(db_session: AsyncSession) -> None:
    await _add_rule(db_session, "Seal Row", "back_straight_min", 155.0)

    assert await load_thresholds(db_session, "Seal Row") == {"back_straight_min": 155.0}


@pytest.mark.asyncio
async def test_bo_qua_dong_khong_phai_khoa_may(db_session: AsyncSession) -> None:
    """Schema gốc seed sẵn vài dòng đặt tên mô tả tiếng Việt.

    Những dòng đó phải bị bỏ qua chứ không được làm hỏng cả bộ ngưỡng của bài.
    """
    exercise = Exercise(name="Squat", is_active=True)
    db_session.add(exercise)
    await db_session.flush()
    db_session.add(
        ExercisePostureRule(
            exercise_id=exercise.id,
            rule_name="Góc đầu gối (hip-knee-ankle)",  # mô tả, không phải khoá
            joint_a="Hip", joint_b="Knee", joint_c="Ankle",
            min_angle=70, max_angle=100,
        )
    )
    db_session.add(
        ExercisePostureRule(
            exercise_id=exercise.id,
            rule_name="knee_depth",  # khoá máy hợp lệ
            joint_a="Hip", joint_b="Knee", joint_c="Ankle",
            max_angle=88,
        )
    )
    await db_session.flush()

    assert await load_thresholds(db_session, "Squat") == {"knee_depth": 88.0}


@pytest.mark.asyncio
async def test_bo_qua_dong_thieu_gia_tri(db_session: AsyncSession) -> None:
    """Khoá đúng nhưng cột giá trị để trống thì phải rơi về mặc định."""
    exercise = Exercise(name="Inverted Row", is_active=True)
    db_session.add(exercise)
    await db_session.flush()
    db_session.add(
        ExercisePostureRule(
            exercise_id=exercise.id,
            rule_name="back_straight_min",
            joint_a="Shoulder", joint_b="Hip", joint_c="Knee",
            min_angle=None,  # quên điền
        )
    )
    await db_session.flush()

    assert await load_thresholds(db_session, "Inverted Row") == {}


# ─────────────────────────────────────────────────────────────────────
# Ngưỡng đọc được phải thật sự đổi cách chấm
# ─────────────────────────────────────────────────────────────────────

def test_khong_co_nguong_rieng_thi_dung_mac_dinh() -> None:
    analyzer = SquatAnalyzer()
    assert analyzer.threshold("back_straight_min", 150.0) == 150.0
    assert analyzer.rep_counter.down_threshold == KNEE_DEPTH_THRESHOLD


def test_nguong_rieng_doi_ket_qua_cham_diem() -> None:
    """Cùng một tư thế, hai bài chấm khác nhau — đây là mục đích của cả cơ chế.

    Lưng 120° là "cúi quá" với squat tự do (mặc định ≥150°), nhưng đúng chuẩn
    với `Machine Hack Squat` vì thân tựa vào đệm nghiêng của máy.
    """
    # Để 130° cách xa cả hai ngưỡng, tránh so sánh sát biên với số thực.
    pose = squat_pose(120.0, back_angle=130.0)

    mac_dinh = SquatAnalyzer().analyze(pose)
    hack_squat = SquatAnalyzer(thresholds={"back_straight_min": 120.0}).analyze(pose)

    assert any("Lưng bị cúi" in e for e in mac_dinh.errors)
    assert not any("Lưng bị cúi" in e for e in hack_squat.errors)


def test_nguong_rieng_doi_ca_cach_dem_rep() -> None:
    """Ngưỡng độ sâu cũng là ngưỡng đếm rep, nên ghi đè phải ăn vào RepCounter.

    Xuống 85° tính là một rep với ngưỡng mặc định 95°, nhưng không tính với
    bài đòi hỏi sâu hơn hẳn (70°).

    Khoảng cách giữa hai ngưỡng phải lớn hơn 10°: RepCounter còn một biên dung
    sai "gần đáy" rộng 10° cho trường hợp FPS thấp bỏ lỡ frame chạm đáy, nên
    hai ngưỡng sát nhau sẽ cho cùng kết quả.
    """
    angles = rep_sequence(170, 85)

    mac_dinh = SquatAnalyzer()
    hack_squat = SquatAnalyzer(thresholds={"knee_depth": 70.0})
    for angle in angles:
        pose = squat_pose(angle, 175.0)
        mac_dinh.analyze(pose)
        hack_squat.analyze(pose)

    assert mac_dinh.rep_counter.rep_count == 1
    assert hack_squat.rep_counter.rep_count == 0


def test_seal_row_khong_con_bi_bao_lung_cong_oan() -> None:
    """Bài thật đã thúc đẩy toàn bộ việc này.

    `Seal Row` nằm sấp trên ghế, thân duỗi thẳng ~160°. RowAnalyzer mặc định
    đòi ≥100° nên tư thế đó không bị báo lỗi — nhưng ngưỡng riêng 155° mới
    phản ánh đúng yêu cầu của bài, và một tư thế thân 130° (chân buông thõng)
    phải bị bắt.
    """
    pose_sai = arm_pose(120.0, back_angle=130.0)

    mac_dinh = RowAnalyzer().analyze(pose_sai)
    seal_row = RowAnalyzer(thresholds={"back_straight_min": 155.0}).analyze(pose_sai)

    assert BACK_STRAIGHT_MIN == 100.0  # ngưỡng chung, quá lỏng cho seal row
    assert not any("Lưng bị cong" in e for e in mac_dinh.errors)
    assert any("Lưng bị cong" in e for e in seal_row.errors)
