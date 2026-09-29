"""Unit tests cho angle_utils."""

import math

import pytest

from app.ml.angle_utils import calculate_angle, calculate_angle_3d
from app.ml.pose_estimator import Keypoint


def kp(x: float, y: float) -> Keypoint:
    """Tạo Keypoint 2D đơn giản cho test."""
    return Keypoint(x=x, y=y, z=0.0, visibility=1.0)


def test_straight_line_returns_180() -> None:
    """Ba điểm thẳng hàng phải cho góc 180°."""
    a = kp(0.0, 0.0)
    b = kp(1.0, 0.0)
    c = kp(2.0, 0.0)
    angle = calculate_angle(a, b, c)
    assert abs(angle - 180.0) < 0.01


def test_right_angle_returns_90() -> None:
    """Góc vuông phải cho 90°."""
    a = kp(0.0, 1.0)
    b = kp(0.0, 0.0)
    c = kp(1.0, 0.0)
    angle = calculate_angle(a, b, c)
    assert abs(angle - 90.0) < 0.01


def test_acute_angle() -> None:
    """Kiểm tra góc nhọn ~ 45°."""
    a = kp(0.0, 1.0)
    b = kp(0.0, 0.0)
    c = kp(1.0, 1.0)
    angle = calculate_angle(a, b, c)
    assert abs(angle - 45.0) < 0.5


def _pixel_to_kp(px: float, py: float, width: int, height: int) -> Keypoint:
    """Đặt một điểm theo PIXEL rồi chuẩn hoá như MediaPipe/ML Kit (x/W, y/H)."""
    return Keypoint(x=px / width, y=py / height, z=0.0, visibility=1.0, aspect=width / height)


@pytest.mark.parametrize(("width", "height"), [(480, 720), (720, 1280), (640, 480), (1280, 720)])
@pytest.mark.parametrize("rotation", [0, 20, 45, 70, 90, 135])
def test_goc_dung_khi_anh_khong_vuong(width: int, height: int, rotation: int) -> None:
    """Khớp có góc THẬT 95° trong không gian pixel phải đo ra 95° dù ảnh dọc hay
    ngang và chi xoay hướng nào — bug 30/09/2026: bỏ qua tỉ lệ ảnh làm ảnh dọc
    2:3 méo góc tới ~23°, đủ để hụt rep hoặc báo 'chưa đủ sâu' oan."""
    true_deg = 95.0
    cx, cy, length = width / 2, height / 2, 0.3 * min(width, height)
    r0, r1 = math.radians(rotation), math.radians(rotation + true_deg)
    a = _pixel_to_kp(cx + length * math.cos(r0), cy + length * math.sin(r0), width, height)
    b = _pixel_to_kp(cx, cy, width, height)
    c = _pixel_to_kp(cx + length * math.cos(r1), cy + length * math.sin(r1), width, height)

    assert calculate_angle(a, b, c) == pytest.approx(true_deg, abs=0.05)
    assert calculate_angle_3d(a, b, c) == pytest.approx(true_deg, abs=0.05)


def test_khong_co_aspect_van_nhu_cu() -> None:
    """Keypoint không khai aspect (mặc định 1,0) cho đúng kết quả cũ — mọi nơi
    chưa biết kích thước ảnh (test dựng tay, chuẩn tham chiếu cũ) không đổi."""
    a = Keypoint(x=0.0, y=1.0, z=0.0, visibility=1.0)
    b = Keypoint(x=0.0, y=0.0, z=0.0, visibility=1.0)
    c = Keypoint(x=1.0, y=1.0, z=0.0, visibility=1.0)
    assert calculate_angle(a, b, c) == pytest.approx(45.0, abs=0.01)


def test_same_point_does_not_crash() -> None:
    """Hai điểm trùng nhau không được ném exception."""
    a = kp(0.5, 0.5)
    b = kp(0.5, 0.5)
    c = kp(1.0, 0.0)
    angle = calculate_angle(a, b, c)
    assert 0.0 <= angle <= 180.0
