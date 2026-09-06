"""Đọc/ghi ngưỡng tư thế riêng của từng bài tập (`ExercisePostureRules`).

Đây là tầng dữ liệu cho màn admin "AI Config". Phần đọc lúc CHẠY nằm ở
`app/ml/analyzers/thresholds.py` — cố tình tách đôi: đường chạy chỉ cần một
hàm nhẹ, không kéo theo registry hay siêu dữ liệu giao diện, vì nó nằm trong
vòng lặp phân tích từng frame.
"""

from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.ml.analyzers.thresholds import VALUE_COLUMN
from app.models.exercise import Exercise
from app.models.posture_rule import ExercisePostureRule

# Bộ ba khớp ghi vào dòng mới. Analyzer KHÔNG đọc ba cột này — mỗi analyzer đã
# biết sẵn nó đo góc nào — nhưng cột NOT NULL nên vẫn phải điền, và giá trị có
# nghĩa giúp người mở thẳng DB ra đọc hiểu được dòng đó nói về góc nào.
_JOINTS: dict[str, tuple[str, str, str]] = {
    "knee_depth": ("Hip", "Knee", "Ankle"),
    "stand_up_min": ("Hip", "Knee", "Ankle"),
    # Không phải góc: so vị trí ngang của gối với mũi chân, nên bộ ba này chỉ
    # nói "liên quan tới gối và bàn chân" chứ không mô tả một góc thật.
    "knee_overshoot": ("Knee", "Ankle", "FootIndex"),
    "back_straight_min": ("Shoulder", "Hip", "Knee"),
    "hip_down": ("Shoulder", "Hip", "Knee"),
    "hip_up": ("Shoulder", "Hip", "Knee"),
    "hip_asymmetry": ("Shoulder", "Hip", "Knee"),
    "elbow_contracted": ("Shoulder", "Elbow", "Wrist"),
    "elbow_extended": ("Shoulder", "Elbow", "Wrist"),
    "elbow_down": ("Shoulder", "Elbow", "Wrist"),
    "elbow_lockout": ("Shoulder", "Elbow", "Wrist"),
    "elbow_asymmetry": ("Shoulder", "Elbow", "Wrist"),
    "straight_body_min": ("Shoulder", "Hip", "Knee"),
    "hip_sag": ("Shoulder", "Hip", "Knee"),
    "cat": ("Shoulder", "Hip", "Knee"),
    "cow": ("Shoulder", "Hip", "Knee"),
    "shoulder_rest": ("Hip", "Shoulder", "Elbow"),
    "shoulder_raised": ("Hip", "Shoulder", "Elbow"),
    "shoulder_contracted": ("Hip", "Shoulder", "Elbow"),
    "shoulder_extended": ("Hip", "Shoulder", "Elbow"),
    "shoulder_asymmetry": ("Hip", "Shoulder", "Elbow"),
}

# Ngưỡng nào là mốc đếm rep — ghi vào cột `IsRepTrigger` để người đọc DB thấy
# được. Cột này cũng chỉ mang tính tài liệu, analyzer không đọc.
_REP_TRIGGERS = frozenset({
    "knee_depth", "stand_up_min", "hip_down", "hip_up",
    "elbow_contracted", "elbow_extended", "elbow_down", "elbow_lockout",
    "cat", "cow",
    "shoulder_rest", "shoulder_raised", "shoulder_contracted", "shoulder_extended",
})


def analyzer_name_for(exercise_name: str) -> str | None:
    """Tên class analyzer phụ trách bài này, `None` nếu bài không phân tích được.

    Tra bằng tên viết thường, đúng như `routes/realtime.py` làm lúc chạy — nếu
    hai chỗ tra khác nhau thì admin sẽ chỉnh được ngưỡng cho một analyzer khác
    với analyzer thật sự chạy.
    """
    cls = ANALYZER_REGISTRY.get(exercise_name.lower())
    return cls.__name__ if cls is not None else None


async def list_tunable_exercises(
    db: AsyncSession, search: str | None = None
) -> list[tuple[Exercise, str, int]]:
    """Các bài có analyzer, kèm tên analyzer và số ngưỡng đã ghi đè.

    Chỉ trả bài phân tích được: bài không có analyzer thì không có ngưỡng nào
    để chỉnh, đưa vào danh sách chỉ khiến admin chỉnh xong tưởng có tác dụng.
    """
    stmt = select(Exercise).where(func.lower(Exercise.name).in_(ANALYZER_REGISTRY.keys()))
    if search:
        stmt = stmt.where(Exercise.name.ilike(f"%{search}%"))
    exercises = (await db.execute(stmt.order_by(Exercise.name))).scalars().all()

    counts = await _override_counts(db, [e.id for e in exercises])
    return [
        (e, analyzer_name_for(e.name) or "", counts.get(e.id, 0))
        for e in exercises
    ]


async def _override_counts(db: AsyncSession, exercise_ids: list[int]) -> dict[int, int]:
    """Số ngưỡng CÓ HIỆU LỰC của mỗi bài.

    Đếm trong Python chứ không bằng `COUNT(*)` vì hai loại dòng phải bị loại
    trừ, và cả hai điều kiện đó không diễn tả gọn trong SQL: dòng có
    `RuleName` không phải khoá máy (schema gốc seed sẵn vài dòng đặt tên mô tả
    tiếng Việt), và dòng có khoá đúng nhưng cột giá trị bỏ trống. Đếm cả hai
    loại đó vào sẽ báo cho admin một con số cao hơn thực tế.
    """
    if not exercise_ids:
        return {}

    rows = (
        await db.execute(
            select(ExercisePostureRule).where(
                ExercisePostureRule.exercise_id.in_(exercise_ids)
            )
        )
    ).scalars().all()

    counts: dict[int, int] = {}
    for rule in rows:
        column = VALUE_COLUMN.get(rule.rule_name)
        if column is None or getattr(rule, column) is None:
            continue
        counts[rule.exercise_id] = counts.get(rule.exercise_id, 0) + 1
    return counts


async def get_overrides(db: AsyncSession, exercise_id: int) -> dict[str, float]:
    """Ngưỡng đã ghi đè của một bài, dạng `{khoá: giá trị}`.

    Bỏ qua đúng những dòng mà `load_thresholds` cũng bỏ qua lúc chạy, để màn
    admin hiển thị đúng thứ analyzer thật sự dùng.
    """
    rows = (
        await db.execute(
            select(ExercisePostureRule).where(
                ExercisePostureRule.exercise_id == exercise_id
            )
        )
    ).scalars().all()

    out: dict[str, float] = {}
    for rule in rows:
        column = VALUE_COLUMN.get(rule.rule_name)
        if column is None:
            continue
        value = getattr(rule, column)
        if value is not None:
            out[rule.rule_name] = float(value)
    return out


async def replace_overrides(
    db: AsyncSession, exercise_id: int, values: dict[str, float]
) -> dict[str, float]:
    """Đặt lại toàn bộ ngưỡng ghi đè của một bài cho khớp `values`.

    Khoá không có trong `values` sẽ bị XOÁ, tức bài đó quay về ngưỡng mặc định
    của analyzer. Đây là chủ đích: màn admin gửi lên trạng thái đầy đủ nó muốn,
    nên "bỏ tick một ngưỡng" phải thật sự gỡ được ghi đè — nếu chỉ ghi thêm mà
    không xoá thì không có cách nào quay về mặc định ngoài việc sửa tay DB.

    Dòng có `RuleName` không phải khoá máy được giữ nguyên, không đụng tới:
    chúng là dữ liệu của người khác (schema seed sẵn vài dòng mô tả), và xoá
    hộ những gì mình không hiểu là cách làm mất dữ liệu.
    """
    existing = {
        rule.rule_name: rule
        for rule in (
            await db.execute(
                select(ExercisePostureRule).where(
                    ExercisePostureRule.exercise_id == exercise_id
                )
            )
        ).scalars().all()
        if rule.rule_name in VALUE_COLUMN
    }

    for key, value in values.items():
        column = VALUE_COLUMN[key]
        rule = existing.get(key)
        if rule is None:
            joint_a, joint_b, joint_c = _JOINTS[key]
            rule = ExercisePostureRule(
                exercise_id=exercise_id,
                rule_name=key,
                joint_a=joint_a,
                joint_b=joint_b,
                joint_c=joint_c,
                is_rep_trigger=key in _REP_TRIGGERS,
            )
            db.add(rule)
        setattr(rule, column, Decimal(str(round(value, 2))))

    for key, rule in existing.items():
        if key not in values:
            await db.delete(rule)

    await db.flush()
    return await get_overrides(db, exercise_id)
