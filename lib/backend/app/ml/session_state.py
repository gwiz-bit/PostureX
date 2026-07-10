"""Trạng thái của một phiên phân tích real-time cho từng WebSocket connection."""

from app.ml.rep_counter import RepCounter


class SessionState:
    """
    Giữ trạng thái liên tục suốt một WebSocket session.

    Mỗi kết nối có một instance riêng — không chia sẻ giữa các client.
    """

    def __init__(self, exercise: str) -> None:
        self.exercise = exercise.lower().strip()
        self.rep_counter = RepCounter()
        self.last_errors: list[str] = []
        self.frame_count: int = 0
        self.correct_frames: int = 0

    def record_frame(self, errors: list[str]) -> None:
        """Ghi lại kết quả frame để tính tỉ lệ chính xác."""
        self.frame_count += 1
        if not errors:
            self.correct_frames += 1
        self.last_errors = errors

    @property
    def accuracy(self) -> float:
        """Tỉ lệ frame đúng kỹ thuật tính theo phần trăm."""
        if self.frame_count == 0:
            return 0.0
        return round(self.correct_frames / self.frame_count * 100, 1)
