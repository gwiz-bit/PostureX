"""Model hai bảng nhóm cơ — `MuscleGroups` và bảng nối `ExerciseMuscleGroups`.

Giống `Exercise`, hai bảng này đã có sẵn trong schema gốc
(sql/postureX123_schema.sql) và đã được seed 10 nhóm cơ, nhưng chưa có model
nào nối vào nên backend không đọc được — thư viện bài tập vì thế chỉ là một
danh sách phẳng, không lọc theo nhóm cơ được.

Bảng do schema quản lý, không tạo/drop qua create_tables.py.

Cố ý KHÔNG khai báo `relationship()`: chỗ duy nhất cần dữ liệu này là màn
thư viện bài tập, và nó cần đúng một thứ — map {exercise_id -> [tên nhóm cơ]}
cho cả trang. Lấy bằng một câu join tường minh trong crud/exercise.py rẻ hơn
và dễ đọc hơn là để lazy-load bắn N+1 query khi serialize 400 bài.
"""

from sqlalchemy import Boolean, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class MuscleGroup(Base):
    __tablename__ = "MuscleGroups"

    id: Mapped[int] = mapped_column("MuscleGroupId", primary_key=True)
    name: Mapped[str] = mapped_column("Name", String(50), unique=True, nullable=False)


class ExerciseMuscleGroup(Base):
    """Bảng nối bài tập <-> nhóm cơ. Khoá chính là cặp (ExerciseId, MuscleGroupId).

    `is_primary` đánh dấu nhóm cơ chính của bài. Script import đặt cờ này theo
    thư mục chứa file video, vì đó là cách nguồn video đã phân loại bài tập.
    """

    __tablename__ = "ExerciseMuscleGroups"

    exercise_id: Mapped[int] = mapped_column(
        "ExerciseId", ForeignKey("Exercises.ExerciseId", ondelete="CASCADE"), primary_key=True
    )
    muscle_group_id: Mapped[int] = mapped_column(
        "MuscleGroupId",
        ForeignKey("MuscleGroups.MuscleGroupId", ondelete="CASCADE"),
        primary_key=True,
    )
    is_primary: Mapped[bool] = mapped_column("IsPrimary", Boolean, default=False)
