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
    left_shoulder: float | None = None
    right_shoulder: float | None = None
    left_ankle: float | None = None
    right_ankle: float | None = None
    back_angle: float | None = None


class Point(BaseModel):
    """Tọa độ chuẩn hóa (0-1, theo khung hình gốc) của một khớp — khác
    với KeyAngles (giá trị góc đã tính sẵn); dùng để vẽ skeleton overlay
    đè lên camera preview phía client."""
    x: float
    y: float
    visibility: float


class FrameAnalysisResult(BaseModel):
    """Phản hồi gửi về client sau mỗi frame."""
    rep_count: int
    errors: list[str]       # danh sách lỗi tiếng Việt
    correct: bool           # True nếu không có lỗi trong frame này
    key_angles: KeyAngles
    phase: str              # "going_down" / "bottom" / "going_up" / "top"
    # Khớp theo tên (vd "left_knee") — None nếu không phát hiện được người.
    # Chỉ gồm các khớp analyzer thực sự dùng để tính góc/lỗi (khác nhau tuỳ
    # bài — squat không có khuỷu tay, curl không có gối), KHÔNG phải để vẽ
    # khung xương đầy đủ. Xem `all_keypoints` cho việc đó.
    keypoints: dict[str, Point] | None = None
    # TOÀN BỘ khớp MediaPipe nhận diện được (trừ đầu ngón tay — quá nhỏ, dễ
    # nhiễu), không phụ thuộc analyzer đang chạy là gì. Route
    # (`routes/realtime.py`) tự gán field này SAU KHI analyzer trả về kết
    # quả — analyzer không biết và không cần biết trường này tồn tại, nên
    # 16 file analyzer không phải sửa gì khi thêm nó. Dùng để vẽ khung
    # xương chi tiết (mặt, khuỷu tay, cổ tay...) phía client, độc lập với
    # `keypoints` (vẫn giữ nguyên cho phần tính toán/debug góc).
    all_keypoints: dict[str, Point] | None = None
    # "Độ giống bài mẫu" (0-100), so chuỗi góc live với chuẩn trích từ video
    # mẫu qua Subsequence DTW — xem `app/ml/similarity_scorer.py`. `None`
    # khi bài chưa có chuẩn tham chiếu (đa số — mới có 113/204 bài, xem
    # CHANGELOG 11/09/2026 (3)) HOẶC cửa sổ live chưa đủ frame để tính, KHÔNG
    # phải điểm 0 — client không nên hiểu `None` là "tập sai hoàn toàn".
    # Route tự gán field này SAU KHI analyzer trả về, giống `all_keypoints`
    # — không analyzer nào cần biết trường này tồn tại.
    similarity_score: float | None = None
