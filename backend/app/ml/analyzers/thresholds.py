"""Ngưỡng góc theo từng bài tập, đọc từ bảng `ExercisePostureRules`.

BÀI TOÁN
--------
Chỉ có 16 analyzer cho 197 bài tập, nên mọi biến thể cùng họ đang bị chấm bằng
đúng một bộ ngưỡng. Có những chỗ sai rõ ràng: `Seal Row` nằm sấp trên ghế
nhưng dùng chung ngưỡng "lưng thẳng ≥100°" với `Barbell Bent Over Row` cúi
45°; `Machine Hack Squat` tựa thân vào đệm nhưng dùng chung ngưỡng lưng ≥150°
với `Barbell Squat` thân tự do.

CÁCH GIẢI (hướng lai)
---------------------
Analyzer giữ nguyên phần logic phức tạp — gối vượt mũi chân, lệch hai bên,
nhận biết tư thế nằm ngang — vì những luật đó không diễn tả được bằng một
bảng min/max. Chỉ riêng CON SỐ ngưỡng thì đọc từ DB theo từng bài.

Bài nào không có dòng nào trong `ExercisePostureRules` sẽ dùng nguyên ngưỡng
mặc định hardcode trong analyzer. Nhờ vậy không phải nhập đủ 417 bài mới dùng
được: 106 bài đang chạy giữ nguyên hành vi, chỉ bài nào được nhập ngưỡng
riêng mới khác đi.

KHOÁ NGƯỠNG
-----------
`ExercisePostureRules.RuleName` phải khớp đúng một khoá trong `VALUE_COLUMN`
bên dưới. Dòng nào có tên khác sẽ bị bỏ qua có chủ đích — trong đó có 4 dòng
seed sẵn của schema gốc, vốn đặt tên mô tả bằng tiếng Việt ("Góc đầu gối
(hip-knee-ankle)") chứ không phải khoá máy.

Mỗi khoá lấy giá trị từ cột nào là cố định và được liệt kê tường minh, thay vì
đoán theo cột nào khác null: ngưỡng "lưng phải thẳng ít nhất 150°" là một cận
DƯỚI (`MinAngle`), còn "gối phải gập xuống dưới 95°" là một cận TRÊN
(`MaxAngle`). Nhầm hai cột này thì ngưỡng đảo chiều mà không có lỗi nào báo.
"""

import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.exercise import Exercise
from app.models.posture_rule import ExercisePostureRule

logger = logging.getLogger(__name__)

# Khoá ngưỡng -> cột chứa giá trị trong ExercisePostureRules.
#
# Đặt tên theo ngữ nghĩa động tác, không theo tên hằng số trong code, để người
# nhập dữ liệu không phải đọc mã nguồn mới hiểu mình đang chỉnh gì.
VALUE_COLUMN: dict[str, str] = {
    # Chung cho nhiều analyzer
    "back_straight_min": "min_angle",   # góc thân tối thiểu để coi là lưng thẳng
    # Squat / Lunge
    "knee_depth": "max_angle",          # gối phải gập xuống dưới góc này mới đủ sâu
    "stand_up_min": "min_angle",        # lên trên góc này = đã đứng thẳng lại
    # Squat / Lunge / Deadlift
    #
    # Khoá DUY NHẤT không phải góc: đây là tỉ lệ theo chiều rộng frame (0.05 =
    # gối được phép vượt mũi chân 5% chiều rộng khung hình). Vì thế nó lấy giá
    # trị từ cột `Tolerance` chứ không phải Min/MaxAngle — nhét một tỉ lệ 0.05
    # vào cột mang tên "góc" sẽ đánh lừa mọi người đọc thẳng DB.
    "knee_overshoot": "tolerance",
    # Deadlift / Hip thrust
    "hip_down": "max_angle",
    "hip_up": "min_angle",
    "hip_asymmetry": "max_angle",       # lệch hai hông quá mức này là đẩy lệch bên
    # Row
    "elbow_contracted": "max_angle",
    "elbow_extended": "min_angle",
    # Bench press / Overhead press
    "elbow_down": "max_angle",
    "elbow_lockout": "min_angle",
    "elbow_asymmetry": "max_angle",
    # Plank
    "straight_body_min": "min_angle",
    "hip_sag": "max_angle",
    # Cat-Cow
    "cat": "max_angle",
    "cow": "min_angle",
    # Lateral raise / front raise / rear delt fly
    "shoulder_rest": "max_angle",
    "shoulder_raised": "min_angle",
    # Chest fly / pec fly — chiều ngược lateral raise, khoá khác nhưng cùng
    # cột (đỉnh rep vẫn là max_angle, nghỉ vẫn là min_angle).
    "shoulder_contracted": "max_angle",
    "shoulder_extended": "min_angle",
    # Chung cho cả hai (lệch hai tay quá mức này).
    "shoulder_asymmetry": "max_angle",
    # Calf raise
    "ankle_rest": "max_angle",
    "ankle_raised": "min_angle",
    "ankle_asymmetry": "max_angle",
    # Leg extension
    "knee_rest": "max_angle",
    "knee_extended": "min_angle",
    "knee_asymmetry": "max_angle",
    # Tricep extension/pushdown — "elbow_extended" dùng chung khoá với Curl
    # (cùng cột min_angle, cùng ý nghĩa "đã duỗi thẳng").
    "elbow_bent": "max_angle",
}


async def load_thresholds(db: AsyncSession, exercise_name: str) -> dict[str, float]:
    """Ngưỡng ghi đè cho một bài tập, tra theo tên bài (không phân biệt hoa/thường).

    Trả `{}` nếu bài không tồn tại hoặc chưa có ngưỡng riêng — analyzer sẽ tự
    dùng mặc định của nó.
    """
    rows = (
        await db.execute(
            select(ExercisePostureRule)
            .join(Exercise, Exercise.id == ExercisePostureRule.exercise_id)
            .where(Exercise.name == exercise_name)
        )
    ).scalars().all()

    thresholds: dict[str, float] = {}
    for rule in rows:
        column = VALUE_COLUMN.get(rule.rule_name)
        if column is None:
            # Dòng mô tả cho người đọc, không phải khoá máy — bỏ qua trong im
            # lặng ở mức debug, vì schema gốc seed sẵn vài dòng kiểu đó.
            logger.debug("Bỏ qua rule '%s' của '%s': không phải khoá ngưỡng", rule.rule_name, exercise_name)
            continue
        value = getattr(rule, column)
        if value is None:
            logger.warning(
                "Rule '%s' của '%s' thiếu giá trị ở cột %s — bỏ qua, dùng mặc định.",
                rule.rule_name, exercise_name, column,
            )
            continue
        thresholds[rule.rule_name] = float(value)

    if thresholds:
        logger.info("Bài '%s' dùng %d ngưỡng riêng: %s", exercise_name, len(thresholds), thresholds)
    return thresholds
