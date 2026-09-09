"""Test phần THUẦN của pose_estimator.py — không đụng MediaPipe/file model,
chỉ `DISPLAY_LANDMARK_NAMES` và `named_keypoints` (dùng để dựng khung xương
hiển thị đầy đủ, xem CHANGELOG 09/09/2026 và docstring trong pose_estimator.py)."""

from app.ml.pose_estimator import (
    DISPLAY_LANDMARK_NAMES,
    Keypoint,
    PoseEstimator,
    named_keypoints,
)


def test_loai_dau_ngon_tay_khoi_danh_sach_hien_thi() -> None:
    for name in ("left_pinky", "right_pinky", "left_index", "right_index",
                 "left_thumb", "right_thumb"):
        assert name not in DISPLAY_LANDMARK_NAMES


def test_giu_du_cac_khop_chinh() -> None:
    for name in ("nose", "left_eye", "right_eye", "left_shoulder", "right_shoulder",
                 "left_elbow", "right_elbow", "left_wrist", "right_wrist",
                 "left_hip", "right_hip", "left_knee", "right_knee",
                 "left_ankle", "right_ankle"):
        assert name in DISPLAY_LANDMARK_NAMES


def test_khong_trung_ten_nao():
    assert len(DISPLAY_LANDMARK_NAMES) == len(set(DISPLAY_LANDMARK_NAMES))


def test_named_keypoints_gan_dung_ten_theo_dung_chi_so() -> None:
    keypoints = [Keypoint(x=i / 100, y=0.0, z=0.0, visibility=1.0) for i in range(33)]
    result = named_keypoints(keypoints)

    for name in DISPLAY_LANDMARK_NAMES:
        idx = PoseEstimator.LANDMARK_NAMES[name]
        assert result[name].x == idx / 100

    # Đầu ngón tay không xuất hiện trong kết quả dù có mặt trong danh sách gốc.
    assert "left_pinky" not in result
