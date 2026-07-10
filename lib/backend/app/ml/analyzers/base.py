"""Abstract base class cho tất cả analyzer bài tập."""

from abc import ABC, abstractmethod

from app.ml.pose_estimator import Keypoint
from app.ml.rep_counter import RepCounter
from app.schemas.analysis import FrameAnalysisResult


class ExerciseAnalyzer(ABC):
    """
    Mỗi loại bài tập kế thừa class này và implement phương thức analyze.

    analyze() nhận 33 keypoints, cập nhật RepCounter, trả FrameAnalysisResult.
    """

    def __init__(self, rep_counter: RepCounter) -> None:
        self.rep_counter = rep_counter

    @abstractmethod
    def analyze(self, keypoints: list[Keypoint]) -> FrameAnalysisResult:
        """Phân tích một frame và trả phản hồi cho client."""
        ...
