"""Nhập ngưỡng góc riêng cho từng bài tập vào `ExercisePostureRules`.

VÌ SAO CẦN
----------
Thư viện có 417 bài nhưng chỉ 9 analyzer, nên mọi biến thể cùng họ đang bị
chấm bằng đúng một bộ ngưỡng. Với nhiều bài thì ngưỡng chung sai rõ ràng —
xem phần lý do đi kèm từng dòng bên dưới.

Script chỉ nhập cho những bài mà ngưỡng chung SAI, không nhập cho cả 417 bài:
bài nào không có dòng nào ở đây vẫn dùng ngưỡng mặc định trong analyzer và
chạy y như trước.

CÁCH DÙNG
---------
    venv/bin/python scripts/seed_posture_rules.py --dry-run   # xem trước
    venv/bin/python scripts/seed_posture_rules.py             # ghi thật

Chạy lại nhiều lần an toàn: mỗi (bài, khoá ngưỡng) chỉ có một dòng, chạy lại
sẽ cập nhật giá trị chứ không nhân bản.

Ngưỡng ở đây là ƯỚC LƯỢNG THEO CƠ CHẾ ĐỘNG TÁC, chưa đo trên người thật.
Sau khi thử với camera thì sửa số ở đây rồi chạy lại.
"""

import argparse
import asyncio
import sys
from pathlib import Path

from sqlalchemy import select

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import AsyncSessionLocal, engine  # noqa: E402
from app.ml.analyzers.thresholds import VALUE_COLUMN  # noqa: E402
from app.models.exercise import Exercise  # noqa: E402
from app.models.posture_rule import ExercisePostureRule  # noqa: E402

# (tên bài, khoá ngưỡng, giá trị, bộ ba khớp, lý do)
#
# Bộ ba khớp chỉ để làm tài liệu cho người đọc dữ liệu — analyzer không đọc,
# vì mỗi analyzer đã biết sẵn nó đo góc nào.
RULES: list[tuple[str, str, float, tuple[str, str, str], str]] = [
    # ─── Seal Row ────────────────────────────────────────────────────────
    # Nằm sấp trên ghế cao, thân song song mặt sàn và được ghế đỡ hoàn toàn.
    # RowAnalyzer mặc định đòi góc vai-hông-gối ≥100° (tư thế cúi 45° của
    # barbell row). Người nằm sấp duỗi thẳng người thì góc đó ~170-180°, nên
    # ngưỡng 100° không bao giờ chạm tới — nhưng nếu chân buông thõng xuống
    # thì góc tụt hẳn và bị báo "lưng bị cong" oan. Nâng ngưỡng lên đúng với
    # tư thế nằm duỗi thẳng.
    ("Seal Row", "back_straight_min", 155.0, ("Shoulder", "Hip", "Knee"),
     "nằm sấp trên ghế, thân phải thẳng chứ không cúi 45° như barbell row"),

    # ─── Machine Hack Squat ──────────────────────────────────────────────
    # Lưng tựa vào đệm nghiêng của máy, thân không dựng đứng như squat tự do.
    # SquatAnalyzer mặc định đòi góc vai-hông-gối ≥150°; tựa đệm nghiêng thì
    # góc này nhỏ hơn hẳn dù kỹ thuật hoàn toàn đúng.
    ("Machine Hack Squat", "back_straight_min", 120.0, ("Shoulder", "Hip", "Knee"),
     "thân tựa đệm nghiêng của máy, không dựng đứng như squat tự do"),
    # Máy đỡ toàn bộ thân nên xuống sâu hơn squat tự do được, và đó cũng là
    # mục đích của bài — hạ ngưỡng độ sâu cho khớp thực tế.
    ("Machine Hack Squat", "knee_depth", 90.0, ("Hip", "Knee", "Ankle"),
     "máy đỡ thân nên xuống sâu hơn được, đòi hỏi cao hơn squat tự do"),

    # ─── Reverse Hack Squat ──────────────────────────────────────────────
    # Cùng máy nhưng quay mặt vào đệm — thân vẫn tựa, cùng lý do như trên.
    ("Reverse Hack Squat", "back_straight_min", 120.0, ("Shoulder", "Hip", "Knee"),
     "cùng máy hack squat, thân tựa đệm"),

    # ─── Inverted Row ────────────────────────────────────────────────────
    # Treo ngửa dưới thanh, thân thẳng như một tấm ván chứ không cúi.
    ("Inverted Row", "back_straight_min", 155.0, ("Shoulder", "Hip", "Knee"),
     "treo ngửa dưới thanh, thân thẳng như plank chứ không cúi 45°"),

    # ─── Chest Supported Dumbbell Row ────────────────────────────────────
    # Ngực tì vào ghế nghiêng, thân được đỡ nên không cúi tự do.
    ("Chest Supported Dumbbell Row", "back_straight_min", 140.0, ("Shoulder", "Hip", "Knee"),
     "ngực tì ghế nghiêng, thân được đỡ nên góc khác barbell row"),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Nhap nguong goc rieng cho tung bai tap.")
    parser.add_argument("--dry-run", action="store_true", help="Chi in ra du dinh, khong ghi DB.")
    return parser.parse_args()


async def seed(dry_run: bool) -> None:
    # Bắt lỗi gõ sai khoá ngay trước khi đụng DB: một khoá sai sẽ được ghi
    # xuống bình thường rồi bị bỏ qua lúc chạy, không có lỗi nào báo.
    unknown = {key for _, key, _, _, _ in RULES if key not in VALUE_COLUMN}
    if unknown:
        print(f"LOI: khoa nguong khong hop le: {sorted(unknown)}", file=sys.stderr)
        print(f"     Khoa hop le: {sorted(VALUE_COLUMN)}", file=sys.stderr)
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        created = updated = missing = 0

        for exercise_name, key, value, joints, reason in RULES:
            exercise = (
                await db.execute(select(Exercise).where(Exercise.name == exercise_name))
            ).scalar_one_or_none()

            if exercise is None:
                print(f"  BO QUA  {exercise_name!r}: khong co trong DB")
                missing += 1
                continue

            existing = (
                await db.execute(
                    select(ExercisePostureRule).where(
                        ExercisePostureRule.exercise_id == exercise.id,
                        ExercisePostureRule.rule_name == key,
                    )
                )
            ).scalar_one_or_none()

            column = VALUE_COLUMN[key]
            action = "cap nhat" if existing else "them moi"
            print(f"  {action:<9} {exercise_name:<32} {key:<20} {column}={value}")
            print(f"            ly do: {reason}")

            if dry_run:
                continue

            if existing is not None:
                setattr(existing, column, value)
                updated += 1
            else:
                joint_a, joint_b, joint_c = joints
                rule = ExercisePostureRule(
                    exercise_id=exercise.id,
                    rule_name=key,
                    joint_a=joint_a,
                    joint_b=joint_b,
                    joint_c=joint_c,
                    is_rep_trigger=key in ("knee_depth", "hip_down", "elbow_contracted", "elbow_down"),
                )
                setattr(rule, column, value)
                db.add(rule)
                created += 1

        if dry_run:
            print("\nDRY-RUN: khong ghi gi vao DB.")
            return

        await db.commit()
        print(f"\nThem moi {created} | cap nhat {updated} | bo qua {missing} (bai khong co trong DB)")


async def main(dry_run: bool) -> None:
    try:
        await seed(dry_run)
    finally:
        # Đóng pool tường minh. Thiếu bước này, aiomysql dọn connection trong
        # __del__ sau khi event loop đã đóng và in ra traceback "Event loop is
        # closed" — vô hại nhưng trông như script vừa lỗi.
        await engine.dispose()


if __name__ == "__main__":
    args = parse_args()
    print(f"Che do: {'DRY-RUN' if args.dry_run else 'THUC THI'}\n")
    asyncio.run(main(args.dry_run))
