"""Abstract base class cho tất cả analyzer bài tập."""

from abc import ABC, abstractmethod

from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult


class ExerciseAnalyzer(ABC):
    """
    Mỗi loại bài tập kế thừa class này và implement phương thức analyze.

    analyze() nhận 33 keypoints, cập nhật RepCounter, trả FrameAnalysisResult.

    `thresholds` là các ngưỡng ghi đè riêng cho một bài tập cụ thể, đọc từ
    bảng `ExercisePostureRules` (xem `analyzers/thresholds.py`). Chỉ có 9
    analyzer cho hơn 100 bài, nên nếu không có cơ chế này thì `Seal Row` nằm
    sấp sẽ bị chấm bằng đúng ngưỡng lưng của `Barbell Bent Over Row` cúi 45°.

    Truyền `None` hoặc thiếu khoá thì analyzer dùng hằng số mặc định của nó —
    đó là lý do 106 bài đang chạy không đổi hành vi khi bật cơ chế này lên.
    """

    def __init__(
        self,
        rep_counter: RepCounter,
        thresholds: dict[str, float] | None = None,
    ) -> None:
        self.rep_counter = rep_counter
        self.thresholds = thresholds or {}

    def threshold(self, key: str, default: float) -> float:
        """Ngưỡng riêng của bài tập này, hoặc `default` nếu chưa nhập."""
        return self.thresholds.get(key, default)

    @abstractmethod
    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        """Phân tích một frame và trả phản hồi cho client."""
        ...
