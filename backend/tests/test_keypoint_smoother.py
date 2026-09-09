"""Test bộ làm mượt toạ độ khớp (`KeypointSmoother`) — xác nhận lỗi khung
xương "nhảy loạn" phát hiện khi test trên điện thoại thật ngày 09/09/2026
(xem CHANGELOG)."""

import pytest

from app.ml.keypoint_smoother import KeypointSmoother
from app.ml.pose_estimator import Keypoint


def _kp(x: float, y: float = 0.5, z: float = 0.0, visibility: float = 1.0) -> Keypoint:
    return Keypoint(x=x, y=y, z=z, visibility=visibility)


def test_frame_dau_tien_giu_nguyen() -> None:
    """Chưa có frame trước đó thì không có gì để làm mượt — trả nguyên vẹn."""
    smoother = KeypointSmoother(alpha=0.5)
    frame = [_kp(0.3)]
    result = smoother.smooth(frame)
    assert result[0].x == 0.3


def test_lam_muot_giam_bien_do_nhay() -> None:
    """Một cú nhảy đột ngột (nhiễu MediaPipe) phải bị GIẢM BỚT, không đi
    thẳng tới vị trí mới ngay lập tức — đúng mục đích chống 'nhảy loạn'."""
    smoother = KeypointSmoother(alpha=0.3)
    smoother.smooth([_kp(0.5)])  # frame 1: chốt vị trí nền
    result = smoother.smooth([_kp(0.9)])  # frame 2: nhảy đột ngột sang 0.9

    # Công thức EMA: 0.3*0.9 + 0.7*0.5 = 0.62 — nằm giữa, không nhảy hẳn tới 0.9.
    assert result[0].x == pytest.approx(0.62)
    assert 0.5 < result[0].x < 0.9


def test_hoi_tu_ve_gia_tri_moi_khi_giu_nguyen_lien_tuc() -> None:
    """Giữ yên một tư thế đủ lâu thì vị trí làm mượt phải hội tụ về đúng vị
    trí thật — làm mượt không được để lại độ trễ vĩnh viễn."""
    smoother = KeypointSmoother(alpha=0.5)
    for _ in range(20):
        result = smoother.smooth([_kp(0.8)])
    assert result[0].x == pytest.approx(0.8, abs=1e-4)


def test_mat_nguoi_thi_xoa_trang_thai_cu() -> None:
    """None (không phát hiện được người) phải xoá sạch trạng thái làm mượt
    — nối tư thế MỚI (có thể là người khác, hoặc người cũ đã đổi vị trí hẳn)
    với vị trí làm mượt CŨ sẽ tạo chuyển động giả, còn tệ hơn không làm mượt."""
    smoother = KeypointSmoother(alpha=0.5)
    smoother.smooth([_kp(0.1)])
    assert smoother.smooth(None) is None

    # Frame kế tiếp phải nhận nguyên vẹn, không bị kéo về phía 0.1 cũ.
    result = smoother.smooth([_kp(0.9)])
    assert result[0].x == 0.9


def test_so_khop_doi_thi_reset_thay_vi_zip_lech() -> None:
    """Số khớp phát hiện được đổi khác frame trước (hiếm nhưng có thể xảy
    ra) thì phải reset, không được zip lệch chỉ số giữa hai danh sách khác
    độ dài."""
    smoother = KeypointSmoother(alpha=0.5)
    smoother.smooth([_kp(0.1), _kp(0.2)])
    result = smoother.smooth([_kp(0.9)])
    assert result[0].x == 0.9


def test_do_tin_cay_khong_bi_lam_muot() -> None:
    """visibility phải phản ánh ĐÚNG frame mới, không bị trễ theo EMA — nếu
    không is_visible() sẽ vẫn coi một khớp vừa che khuất là 'thấy rõ' thêm
    vài frame."""
    smoother = KeypointSmoother(alpha=0.5)
    smoother.smooth([_kp(0.5, visibility=1.0)])
    result = smoother.smooth([_kp(0.5, visibility=0.1)])
    assert result[0].visibility == 0.1


def test_alpha_ngoai_khoang_hop_le_bi_tu_choi() -> None:
    with pytest.raises(ValueError):
        KeypointSmoother(alpha=0.0)
    with pytest.raises(ValueError):
        KeypointSmoother(alpha=1.5)
