"""Pydantic schemas cho kết quả phân tích real-time."""

from pydantic import BaseModel


class FrameInitMessage(BaseModel):
    """Message đầu tiên client gửi để khởi tạo phiên."""
    exercise: str  # vd: "squat", "pushup"


class KeyAngles(BaseModel):
    """Các góc khớp quan trọng của một frame."""
    left_knee: float | None = None
    right_knee: float | None = None
    left_hip: float | None = None
    right_hip: float | None = None
    left_elbow: float | None = None
    right_elbow: float | None = None
    back_angle: float | None = None


class FrameAnalysisResult(BaseModel):
    """Phản hồi gửi về client sau mỗi frame."""
    rep_count: int
    errors: list[str]       # danh sách lỗi tiếng Việt
    correct: bool           # True nếu không có lỗi trong frame này
    key_angles: KeyAngles
    phase: str              # "going_down" / "bottom" / "going_up" / "top"
