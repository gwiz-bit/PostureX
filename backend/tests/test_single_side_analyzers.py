"""Test chế độ `single_side` (bài một tay/một chân) — xem `active_side()`
trong `common.py` và `SINGLE_SIDE_EXERCISES` trong `registry.py`.

Khoá lại đúng hành vi mà lượt rà tay checklist 412 bài (13/09/2026) đã sửa:
- KHÔNG bật single_side: một bên nghỉ giữ góc duỗi kéo avg() lên, rep không
  bao giờ đếm được (lỗi gốc khiến các bài này từng bị loại hẳn).
- CÓ bật single_side: active_side() chọn đúng bên đang làm việc, rep đếm
  đúng, và kiểm tra "lệch hai bên" (vốn không hợp lý với bài một bên) bị tắt.
"""

from app.ml.analyzers.curl import CurlAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.row import RowAnalyzer
from tests.pose_builders import arm_pose, hinge_pose


def test_khong_bat_single_side_thi_khong_dem_duoc_rep_mot_ben() -> None:
    """Chứng minh lỗi gốc: tay phải đứng yên duỗi thẳng (150°), tay trái đi
    từ duỗi -> co (150 -> 70) -> duỗi lại (150) — một rep hoàn chỉnh của
    RowAnalyzer bình thường (down=70, up=150) — nhưng avg() hai tay không
    bao giờ chạm ngưỡng co 70° nên không đếm được."""
    analyzer = RowAnalyzer()  # single_side mặc định False
    for left in [150, 130, 100, 70, 100, 130, 150]:
        analyzer.analyze(arm_pose(float(left), right_elbow_angle=150.0))
    assert analyzer.rep_counter.rep_count == 0


def test_single_side_dem_dung_rep_khi_mot_tay_nghi() -> None:
    """Cùng chuỗi góc như trên, chỉ khác bật single_side=True — phải đếm
    đúng 1 rep."""
    analyzer = RowAnalyzer(single_side=True)
    for left in [150, 130, 100, 70, 100, 130, 150]:
        analyzer.analyze(arm_pose(float(left), right_elbow_angle=150.0))
    assert analyzer.rep_counter.rep_count == 1


def test_single_side_khong_bao_lech_ben_curl() -> None:
    """CurlAnalyzer bình thường báo lỗi khi hai tay lệch >25° — nhưng bài
    một tay (single_side=True) thì lệch đó là ĐÚNG bản chất bài tập, không
    phải lỗi kỹ thuật."""
    without_flag = CurlAnalyzer().analyze(arm_pose(150.0, right_elbow_angle=70.0))
    assert any("không đều" in e for e in without_flag.errors)

    with_flag = CurlAnalyzer(single_side=True).analyze(arm_pose(150.0, right_elbow_angle=70.0))
    assert not any("không đều" in e for e in with_flag.errors)


def test_single_side_khong_bao_lech_hong_hip_thrust() -> None:
    """Cùng ý tưởng cho HipThrustAnalyzer (bài một chân: B Stance/Single
    Leg Hip Thrust) — ngưỡng lệch hông 15° vốn để bắt lỗi đẩy lệch bên,
    không áp dụng được cho bài một chân có chủ đích."""
    without_flag = HipThrustAnalyzer().analyze(hinge_pose(150.0, right_hip_angle=110.0))
    assert any("lệch một bên" in e for e in without_flag.errors)

    with_flag = HipThrustAnalyzer(single_side=True).analyze(hinge_pose(150.0, right_hip_angle=110.0))
    assert not any("lệch một bên" in e for e in with_flag.errors)


def test_single_side_van_dem_rep_dung_khi_chan_kia_thuc_su_lech() -> None:
    """Chân/tay 'nghỉ' trong bài một bên hiếm khi giữ NGUYÊN một góc suốt —
    active_side() vẫn phải chọn đúng bên đang hạ thấp hơn (đang làm việc)
    bất kể bên kia dao động nhẹ, không chỉ khi bên kia đứng yên tuyệt đối."""
    analyzer = HipThrustAnalyzer(single_side=True)
    # Chân phải (không làm việc) dao động nhẹ quanh 160-170° trong khi chân
    # trái đi trọn một rep 165 -> 110 -> 165.
    sequence = [
        (165.0, 168.0),
        (140.0, 165.0),
        (110.0, 170.0),
        (140.0, 166.0),
        (165.0, 169.0),
    ]
    for left, right in sequence:
        analyzer.analyze(hinge_pose(left, right_hip_angle=right))
    assert analyzer.rep_counter.rep_count == 1
