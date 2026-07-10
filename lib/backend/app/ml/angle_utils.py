"""Tính góc giữa ba điểm khớp bằng NumPy."""

import numpy as np

from app.ml.pose_estimator import Keypoint


def calculate_angle(a: Keypoint, b: Keypoint, c: Keypoint) -> float:
    """
    Tính góc tại khớp b (đỉnh) tạo bởi ba điểm a-b-c.

    Trả về góc tính bằng độ trong khoảng [0, 180].
    """
    vec_ba = np.array([a.x - b.x, a.y - b.y])
    vec_bc = np.array([c.x - b.x, c.y - b.y])

    cosine = np.dot(vec_ba, vec_bc) / (
        np.linalg.norm(vec_ba) * np.linalg.norm(vec_bc) + 1e-8
    )
    # Kẹp giá trị trong [-1, 1] để tránh NaN từ arccos
    angle = np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0)))
    return float(angle)


def calculate_angle_3d(a: Keypoint, b: Keypoint, c: Keypoint) -> float:
    """
    Tính góc tại khớp b dùng cả ba chiều (x, y, z).

    Hữu ích khi cần độ chính xác không gian cao hơn.
    """
    vec_ba = np.array([a.x - b.x, a.y - b.y, a.z - b.z])
    vec_bc = np.array([c.x - b.x, c.y - b.y, c.z - b.z])

    cosine = np.dot(vec_ba, vec_bc) / (
        np.linalg.norm(vec_ba) * np.linalg.norm(vec_bc) + 1e-8
    )
    return float(np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0))))
