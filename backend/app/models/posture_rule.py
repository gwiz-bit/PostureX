"""Model bảng `ExercisePostureRules` — ngưỡng góc riêng cho từng bài tập.

Bảng này đã có sẵn trong schema gốc (sql/postureX123_schema.sql) từ đầu nhưng
chưa có model nào nối vào, nên ngưỡng thật vẫn nằm hardcode trong analyzer và
hai nguồn đã lệch nhau (DB ghi lưng thẳng ≥160°, `squat.py` dùng 150°).

VÌ SAO CẦN NGƯỠNG THEO TỪNG BÀI
--------------------------------
Chỉ có 9 analyzer cho 106 bài tập, nên mọi bài cùng họ đang dùng chung một bộ
ngưỡng. Với nhiều biến thể thì ngưỡng chung sai rõ ràng:

- `Seal Row` nằm sấp trên ghế, nhưng bị chấm bằng cùng ngưỡng "lưng thẳng
  ≥100°" như `Barbell Bent Over Row` cúi 45°.
- `Machine Hack Squat` có thân tựa vào đệm nghiêng, khác hẳn `Barbell Squat`
  thân tự do, mà vẫn dùng chung ngưỡng lưng ≥150°.

Bảng này cho phép ghi đè từng ngưỡng cho từng bài mà không cần viết class
analyzer mới — analyzer giữ nguyên phần logic phức tạp (gối vượt mũi chân,
lệch hai bên, nhận biết tư thế nằm), chỉ đọc con số từ đây.

`RuleName` LÀ KHOÁ MÁY, KHÔNG PHẢI MÔ TẢ
-----------------------------------------
Analyzer tra ngưỡng theo `RuleName`, nên giá trị phải khớp đúng tên khoá mà
analyzer dùng (`back_straight_min`, `knee_depth`, `rep_down`, ...) — xem
`app/ml/analyzers/thresholds.py` để biết danh sách khoá hợp lệ. Dòng nào có
`RuleName` không nằm trong danh sách đó sẽ bị bỏ qua, và bài tập rơi về ngưỡng
mặc định của analyzer. Bốn dòng seed sẵn trong schema dùng tên tiếng Việt mô
tả ("Góc đầu gối (hip-knee-ankle)") nên nằm trong nhóm bị bỏ qua đó.

Các cột `JointA`/`JointB`/`JointC` giữ lại làm tài liệu cho người nhập dữ
liệu — chúng nói ngưỡng này áp cho góc nào — chứ analyzer không đọc, vì mỗi
analyzer đã biết sẵn nó đo bộ khớp nào.

Bảng do schema quản lý, không tạo/drop qua create_tables.py.
"""

from decimal import Decimal

from sqlalchemy import Boolean, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ExercisePostureRule(Base):
    __tablename__ = "ExercisePostureRules"

    id: Mapped[int] = mapped_column("RuleId", primary_key=True)
    exercise_id: Mapped[int] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId", ondelete="CASCADE"), nullable=False
    )
    rule_name: Mapped[str] = mapped_column("RuleName", String(80), nullable=False)

    joint_a: Mapped[str] = mapped_column("JointA", String(40), nullable=False)
    joint_b: Mapped[str] = mapped_column("JointB", String(40), nullable=False)
    joint_c: Mapped[str] = mapped_column("JointC", String(40), nullable=False)

    min_angle: Mapped[Decimal | None] = mapped_column("MinAngle", Numeric(5, 2), nullable=True)
    max_angle: Mapped[Decimal | None] = mapped_column("MaxAngle", Numeric(5, 2), nullable=True)
    target_angle: Mapped[Decimal | None] = mapped_column("TargetAngle", Numeric(5, 2), nullable=True)
    is_rep_trigger: Mapped[bool] = mapped_column("IsRepTrigger", Boolean, default=False)
    tolerance: Mapped[Decimal | None] = mapped_column("Tolerance", Numeric(5, 2), nullable=True)
