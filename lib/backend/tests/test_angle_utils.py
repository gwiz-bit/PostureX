"""Unit tests cho angle_utils."""

import pytest

from app.ml.angle_utils import calculate_angle
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
    import math
    a = kp(0.0, 1.0)
    b = kp(0.0, 0.0)
    c = kp(1.0, 1.0)
    angle = calculate_angle(a, b, c)
    assert abs(angle - 45.0) < 0.5


def test_same_point_does_not_crash() -> None:
    """Hai điểm trùng nhau không được ném exception."""
    a = kp(0.5, 0.5)
    b = kp(0.5, 0.5)
    c = kp(1.0, 0.0)
    angle = calculate_angle(a, b, c)
    assert 0.0 <= angle <= 180.0
