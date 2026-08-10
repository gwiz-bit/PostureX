"""Helper dùng chung cho mọi analyzer bài tập — tách ra từ squat.py để 8+
analyzer sau này không copy-paste lại cùng 3 hàm nhỏ này."""

from app.ml.pose_estimator import Keypoint
from app.schemas.analysis import Point

VISIBILITY_THRESHOLD = 0.5  # Chỉ xét khớp nếu độ tin cậy đủ cao


def is_visible(*kps: Keypoint) -> bool:
    """Trả True nếu tất cả keypoint có visibility đủ cao."""
    return all(kp.visibility >= VISIBILITY_THRESHOLD for kp in kps)


def avg(a: float | None, b: float | None) -> float | None:
    """Trả trung bình hai giá trị; nếu cả hai None thì trả giá trị còn lại
    (hoặc None nếu cả hai đều None) — dùng khi một bên khớp bị che khuất."""
    if a is not None and b is not None:
        return (a + b) / 2
    return a if a is not None else b


def visible_points(joints: dict[str, Keypoint]) -> dict[str, Point]:
    """Chuyển các Keypoint đủ tin cậy thành Point để trả về client vẽ
    skeleton overlay — bỏ qua khớp che khuất/không rõ thay vì gửi tọa độ rác."""
    return {
        name: Point(x=kp.x, y=kp.y, visibility=kp.visibility)
        for name, kp in joints.items()
        if kp.visibility >= VISIBILITY_THRESHOLD
    }
