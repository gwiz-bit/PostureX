"""Tính góc giữa ba điểm khớp bằng NumPy.

Toạ độ khớp chuẩn hoá x theo chiều rộng ảnh, y theo chiều cao ảnh (xem
`Keypoint`), nên phải nhân x với `aspect` (= rộng / cao) để x và y cùng thang
đo pixel rồi mới tính góc — góc không đổi khi phóng cả hai trục cùng một hệ
số, nên chỉ cần tỉ lệ giữa hai trục, không cần kích thước pixel thật. Bỏ bước
này thì ảnh dọc 2:3 méo góc tới ~23° (đo bằng mô phỏng 30/09/2026).
"""

import numpy as np

from app.ml.pose_estimator import Keypoint


def calculate_angle(a: Keypoint, b: Keypoint, c: Keypoint) -> float:
    """
    Tính góc tại khớp b (đỉnh) tạo bởi ba điểm a-b-c.

    Trả về góc tính bằng độ trong khoảng [0, 180].
    """
    s = b.aspect
    vec_ba = np.array([(a.x - b.x) * s, a.y - b.y])
    vec_bc = np.array([(c.x - b.x) * s, c.y - b.y])

    cosine = np.dot(vec_ba, vec_bc) / (
        np.linalg.norm(vec_ba) * np.linalg.norm(vec_bc) + 1e-8
    )
    # Kẹp giá trị trong [-1, 1] để tránh NaN từ arccos
    angle = np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0)))
    return float(angle)


def calculate_angle_3d(a: Keypoint, b: Keypoint, c: Keypoint) -> float:
    """
    Tính góc tại khớp b dùng cả ba chiều (x, y, z).

    Hữu ích khi cần độ chính xác không gian cao hơn. z của MediaPipe cùng thang
    với x (chuẩn hoá theo chiều rộng) nên nhân cùng `aspect` như x.
    """
    s = b.aspect
    vec_ba = np.array([(a.x - b.x) * s, a.y - b.y, (a.z - b.z) * s])
    vec_bc = np.array([(c.x - b.x) * s, c.y - b.y, (c.z - b.z) * s])

    cosine = np.dot(vec_ba, vec_bc) / (
        np.linalg.norm(vec_ba) * np.linalg.norm(vec_bc) + 1e-8
    )
    return float(np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0))))
