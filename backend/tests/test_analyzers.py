"""Test 9 analyzer phân tích tư thế bằng tư thế dựng sẵn.

Trước bộ test này, phần phân tích tư thế — tính năng cốt lõi của app — chưa
từng được kiểm tự động lần nào: chỉ có test cho hàm tính góc và cho bảng ánh
xạ tên bài, không có test nào chạy thử chính việc phân tích. Lần kiểm đầu tiên
lộ ra hai lỗi nặng (đếm rep gấp đôi ở tốc độ tập thông thường; báo "chưa đủ
sâu" suốt lúc đứng lên từ một rep hoàn hảo, kéo điểm chính xác xuống 64,5%).

Các test dưới đây khoá lại hành vi ĐÚNG để hai lỗi đó không quay lại, và để
sau này đổi ngưỡng theo từng bài tập thì biết ngay có làm hỏng gì không.
"""

import pytest

from app.ml.analyzers.bench_press import BenchPressAnalyzer
from app.ml.analyzers.calf_raise import CalfRaiseAnalyzer
from app.ml.analyzers.cat_cow import CatCowAnalyzer
from app.ml.analyzers.chest_fly import ChestFlyAnalyzer
from app.ml.analyzers.curl import CurlAnalyzer
from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.lateral_raise import LateralRaiseAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.overhead_press import OverheadPressAnalyzer
from app.ml.analyzers.plank import PlankAnalyzer
from app.ml.analyzers.row import RowAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.rep_counter import RepCounter
from app.ml.session_state import SessionState
from tests.pose_builders import (
    arm_pose,
    calf_raise_pose,
    hinge_pose,
    plank_pose,
    shoulder_raise_pose,
    spine_pose,
    squat_pose,
)

# 14 frame mỗi chiều ≈ một rep 2,5 giây ở 12 fps — đúng nhịp tập thường gặp,
# và cũng chính là vùng tốc độ mà lỗi đếm gấp đôi từng xảy ra.
FRAMES_PER_DIRECTION = 14


def rep_sequence(top: float, bottom: float, reps: int = 1, steps: int = FRAMES_PER_DIRECTION):
    """Dãy góc của `reps` nhịp lên xuống mượt, như người tập thật."""
    seq: list[float] = []
    for _ in range(reps):
        seq += [top - i * (top - bottom) / steps for i in range(steps + 1)]
        seq += [bottom, bottom]  # giữ ở đáy một nhịp
        seq += [bottom + i * (top - bottom) / steps for i in range(1, steps + 1)]
    return seq


def run(analyzer, build_pose, angles) -> SessionState:
    """Cho analyzer chạy hết dãy góc, trả về SessionState để xem điểm."""
    session = SessionState("test")
    for angle in angles:
        session.record_frame(analyzer.analyze(build_pose(angle)).errors)
    return session


# ─────────────────────────────────────────────────────────────────────
# Đếm rep — phần từng sai gấp đôi
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.parametrize("reps", [1, 3, 5, 10])
def test_dem_dung_so_rep(reps: int) -> None:
    """Đếm đúng số rep thật, không gấp đôi.

    Lỗi cũ: `_min_angle_seen` không được xoá khi người tập đứng thẳng lại, nên
    frame kế tiếp — vẫn đang đi lên nên góc còn tăng — bị nhánh fallback FPS
    thấp hiểu nhầm là vừa chạm đáy lần nữa. 10 rep thật đếm thành 20.
    """
    analyzer = SquatAnalyzer()
    run(analyzer, lambda a: squat_pose(a, 175.0), rep_sequence(170, 85, reps=reps))
    assert analyzer.rep_counter.rep_count == reps


@pytest.mark.parametrize("steps", [4, 8, 14, 25, 40])
def test_dem_dung_o_moi_toc_do_tap(steps: int) -> None:
    """Từ rất nhanh tới rất chậm đều phải đếm đúng.

    Lỗi cũ chỉ xuất hiện ở tốc độ trung bình (góc đổi ≥5°/frame) — tức đúng
    vùng người ta tập thật, trong khi hai đầu cực trị lại đúng. Kiểm cả dải để
    không sửa xong lại lọt vùng khác.
    """
    analyzer = SquatAnalyzer()
    run(analyzer, lambda a: squat_pose(a, 175.0), rep_sequence(170, 85, reps=3, steps=steps))
    assert analyzer.rep_counter.rep_count == 3


def test_nhip_hut_khong_duoc_tinh_rep() -> None:
    """Xuống nông rồi lên lại thì không phải một rep."""
    analyzer = SquatAnalyzer()
    for angle in [170, 150, 130, 140, 160, 170]:
        analyzer.analyze(squat_pose(angle, 175.0))
    assert analyzer.rep_counter.rep_count == 0


def test_van_dem_duoc_khi_bo_lo_frame_day() -> None:
    """Giữ lại lưới an toàn cho FPS thấp: chạm gần đáy rồi lên vẫn tính 1 rep.

    Đây là lý do nhánh fallback tồn tại — sửa lỗi đếm đôi không được làm mất nó.
    """
    counter = RepCounter(down_threshold=95.0, up_threshold=155.0)
    for angle in [170, 130, 100, 108, 140, 170]:
        counter.update(angle)
    assert counter.rep_count == 1


# ─────────────────────────────────────────────────────────────────────
# Rep đúng chuẩn thì không được có lỗi nào
# ─────────────────────────────────────────────────────────────────────

PERFECT_REPS = [
    ("squat", SquatAnalyzer, lambda a: squat_pose(a, 175.0), 170, 85),
    ("lunge", LungeAnalyzer, lambda a: squat_pose(a, 175.0), 170, 88),
    ("row", RowAnalyzer, lambda a: arm_pose(a, back_angle=160.0), 160, 60),
    ("bench_press", BenchPressAnalyzer, lambda a: arm_pose(a), 168, 85),
    ("overhead_press", OverheadPressAnalyzer, lambda a: arm_pose(a), 168, 85),
    ("deadlift", DeadliftAnalyzer, lambda a: hinge_pose(a), 175, 100),
    ("hip_thrust", HipThrustAnalyzer, lambda a: hinge_pose(a), 170, 100),
    ("curl", CurlAnalyzer, lambda a: arm_pose(a), 170, 35),
    ("lateral_raise", LateralRaiseAnalyzer, lambda a: shoulder_raise_pose(a), 15, 85),
    ("chest_fly", ChestFlyAnalyzer, lambda a: shoulder_raise_pose(a), 90, 25),
    ("calf_raise", CalfRaiseAnalyzer, lambda a: calf_raise_pose(a), 138, 80),
]


@pytest.mark.parametrize(("name", "cls", "build", "top", "bottom"), PERFECT_REPS)
def test_rep_dung_chuan_dat_100_phan_tram(name, cls, build, top, bottom) -> None:
    """Một rep thực hiện đúng phải đạt 100% và không nhắc lỗi nào.

    Lỗi cũ: bốn analyzer chấm độ sâu bằng `phase in (bottom, going_up) and góc
    > ngưỡng`, mà lúc đi lên góc đương nhiên lớn hơn ngưỡng — nên rep hoàn hảo
    vẫn bị nhắc "chưa đủ sâu" ở mọi frame đứng lên. Squat chỉ còn 64,5%.
    """
    analyzer = cls()
    session = run(analyzer, build, rep_sequence(top, bottom))

    assert analyzer.rep_counter.rep_count == 1
    assert session.accuracy == 100.0, f"{name} còn báo lỗi oan: {session.last_errors}"


# ─────────────────────────────────────────────────────────────────────
# Bắt đúng lỗi đặc trưng của từng bài
# ─────────────────────────────────────────────────────────────────────

def test_squat_bao_lung_cui() -> None:
    result = SquatAnalyzer().analyze(squat_pose(120.0, back_angle=120.0))
    assert any("Lưng bị cúi" in e for e in result.errors)


def test_squat_bao_goi_vuot_mui_chan() -> None:
    result = SquatAnalyzer().analyze(squat_pose(120.0, 175.0, knee_past_toe=True))
    assert any("vượt quá mũi chân" in e for e in result.errors)


def test_squat_nhac_xuong_nong_dung_MOT_lan() -> None:
    """Nhắc đúng lúc đảo chiều, không lặp lại suốt lúc đi lên."""
    analyzer = SquatAnalyzer()
    warnings = 0
    for angle in [170, 150, 130, 140, 160, 170]:
        if any("chưa đủ sâu" in e for e in analyzer.analyze(squat_pose(angle, 175.0)).errors):
            warnings += 1
    assert warnings == 1


def test_row_bao_lung_cong() -> None:
    result = RowAnalyzer().analyze(arm_pose(120.0, back_angle=80.0))
    assert any("Lưng bị cong" in e for e in result.errors)


def test_bench_press_bao_hai_tay_khong_deu() -> None:
    """Lệch hơn 25° giữa hai tay là đẩy lệch bên."""
    result = BenchPressAnalyzer().analyze(arm_pose(150.0, right_elbow_angle=100.0))
    assert any("không đều" in e for e in result.errors)


def test_overhead_press_bao_hai_tay_khong_deu() -> None:
    result = OverheadPressAnalyzer().analyze(arm_pose(150.0, right_elbow_angle=100.0))
    assert any("không đều" in e for e in result.errors)


def test_curl_bao_hai_tay_khong_deu() -> None:
    result = CurlAnalyzer().analyze(arm_pose(150.0, right_elbow_angle=100.0))
    assert any("không đều" in e for e in result.errors)


def test_curl_nhac_chua_du_cao_dung_MOT_lan() -> None:
    """Cùng cơ chế shallow_reversal của Row — nhắc đúng lúc đảo chiều đi
    xuống, không lặp lại suốt lúc hạ tạ."""
    analyzer = CurlAnalyzer()
    warnings = 0
    for angle in [170, 120, 90, 100, 165, 170]:
        if any("Chưa curl đủ cao" in e for e in analyzer.analyze(arm_pose(angle)).errors):
            warnings += 1
    assert warnings == 1


def test_lateral_raise_bao_hai_tay_khong_deu() -> None:
    result = LateralRaiseAnalyzer().analyze(shoulder_raise_pose(70.0, right_shoulder_angle=20.0))
    assert any("không đều" in e for e in result.errors)


def test_lateral_raise_nhac_chua_du_cao_dung_MOT_lan() -> None:
    """Góc thô (không phải góc bù nội bộ): nghỉ = nhỏ, nâng = lớn — ngược
    chiều mọi analyzer khác trong file, xem chú thích BẪY GÓC trong
    lateral_raise.py. Dãy góc mô phỏng nâng lên nửa chừng (50°, chưa đạt
    ngưỡng 80°) rồi hạ xuống lại."""
    analyzer = LateralRaiseAnalyzer()
    warnings = 0
    for angle in [15, 45, 65, 50, 20, 15]:
        if any("Chưa nâng tay đủ cao" in e for e in analyzer.analyze(shoulder_raise_pose(angle)).errors):
            warnings += 1
    assert warnings == 1


def test_chest_fly_bao_hai_tay_khong_deu() -> None:
    result = ChestFlyAnalyzer().analyze(shoulder_raise_pose(70.0, right_shoulder_angle=20.0))
    assert any("không đều" in e for e in result.errors)


def test_chest_fly_nhac_chua_khep_du_dung_MOT_lan() -> None:
    """Cùng cơ chế shallow_reversal của curl/row: khép nửa chừng rồi mở lại."""
    analyzer = ChestFlyAnalyzer()
    warnings = 0
    for angle in [90, 60, 45, 55, 90, 90]:
        if any("Chưa khép tay đủ" in e for e in analyzer.analyze(shoulder_raise_pose(angle)).errors):
            warnings += 1
    assert warnings == 1


def test_hip_thrust_bao_lech_ben() -> None:
    """Ngưỡng lệch của hip thrust chặt hơn (15°) vì hông dễ đẩy lệch."""
    result = HipThrustAnalyzer().analyze(hinge_pose(150.0, right_hip_angle=120.0))
    assert any("lệch một bên" in e for e in result.errors)


@pytest.mark.parametrize(
    ("cls", "build", "message", "bottom", "half_top"),
    [
        (DeadliftAnalyzer, hinge_pose, "Chưa đứng thẳng", 100.0, 150.0),
        (HipThrustAnalyzer, hinge_pose, "Chưa đẩy hông lên hết", 100.0, 150.0),
        (OverheadPressAnalyzer, arm_pose, "Chưa khoá tay", 85.0, 140.0),
        (CalfRaiseAnalyzer, calf_raise_pose, "Chưa nhón gót đủ cao", 80.0, 115.0),
    ],
)
def test_bao_chua_duoi_het_o_dinh(cls, build, message, bottom, half_top) -> None:
    """Lên nửa chừng rồi hạ xuống thì phải nhắc khoá khớp — đúng MỘT lần.

    Điều kiện cũ là `phase == "top" and góc < ngưỡng_trên`, tự mâu thuẫn vì
    phase chỉ thành "top" đúng lúc góc vượt ngưỡng đó. Cảnh báo này là mã chết,
    chưa từng chạy lần nào ở cả ba bài — kiểm 300+ frame mọi kiểu chuyển động
    không có frame nào thoả mãn.
    """
    analyzer = cls()
    warnings = 0
    top = half_top + 25
    sequence = [
        # Hạ xuống hết đáy (tính 1 rep), rồi chỉ lên NỬA CHỪNG — không được
        # lên hết, vì lên tới đỉnh là đã khoá khớp đúng và không còn gì để nhắc.
        *[top - i * (top - bottom) / FRAMES_PER_DIRECTION for i in range(FRAMES_PER_DIRECTION + 1)],
        bottom,
        half_top - 20, half_top - 5, half_top,
        half_top - 8, half_top - 20,            # quay đầu hạ xuống khi chưa khoá
    ]
    for angle in sequence:
        if any(message in e for e in analyzer.analyze(build(angle)).errors):
            warnings += 1

    assert warnings == 1


@pytest.mark.parametrize(
    ("cls", "build", "top", "bottom"),
    [
        (DeadliftAnalyzer, hinge_pose, 175, 100),
        (HipThrustAnalyzer, hinge_pose, 170, 100),
        (OverheadPressAnalyzer, arm_pose, 168, 85),
        (CalfRaiseAnalyzer, calf_raise_pose, 138, 80),
    ],
)
def test_duoi_het_o_dinh_thi_khong_nhac(cls, build, top, bottom) -> None:
    """Mặt còn lại: duỗi hết thật thì không được nhắc oan."""
    analyzer = cls()
    session = run(analyzer, build, rep_sequence(top, bottom, reps=3))
    assert analyzer.rep_counter.rep_count == 3
    assert session.accuracy == 100.0


def test_calf_raise_bao_lech_ben() -> None:
    result = CalfRaiseAnalyzer().analyze(calf_raise_pose(140.0, right_ankle_angle=100.0))
    assert any("không đều" in e for e in result.errors)


def test_deadlift_bao_goi_vuot_mui_chan() -> None:
    result = DeadliftAnalyzer().analyze(hinge_pose(140.0, knee_past_toe=True))
    assert any("vượt quá mũi chân" in e for e in result.errors)


# ─────────────────────────────────────────────────────────────────────
# Hai bài không đếm rep theo chu kỳ lên/xuống
# ─────────────────────────────────────────────────────────────────────

def test_plank_giu_thang_thi_khong_loi() -> None:
    result = PlankAnalyzer().analyze(plank_pose(175.0))
    assert result.errors == []
    assert result.rep_count == 0  # bài giữ tư thế, không đếm rep


def test_plank_bao_vong_hong() -> None:
    result = PlankAnalyzer().analyze(plank_pose(140.0))
    assert result.errors != []


def test_plank_biet_chua_vao_tu_the() -> None:
    """Đứng thẳng thì chưa phải plank — không được chấm điểm như đang plank."""
    result = PlankAnalyzer().analyze(plank_pose(175.0, horizontal=False))
    assert result.phase != "holding"


def test_cat_cow_dem_chu_ky() -> None:
    """Cat-Cow đếm chu kỳ cong lưng ↔ ưỡn lưng, không phải rep lên xuống."""
    analyzer = CatCowAnalyzer()
    for angle in rep_sequence(175, 130, reps=3):
        analyzer.analyze(spine_pose(angle))
    assert analyzer.rep_counter.rep_count == 3


# ─────────────────────────────────────────────────────────────────────
# Khớp bị che khuất
# ─────────────────────────────────────────────────────────────────────

def test_khop_bi_che_khuat_khong_lam_sap() -> None:
    """Người ra khỏi khung hình thì analyzer phải im lặng, không nổ.

    MediaPipe vẫn trả đủ 33 điểm nhưng visibility thấp; analyzer bỏ qua khớp
    không đủ tin cậy thay vì tính góc trên toạ độ rác.
    """
    result = SquatAnalyzer().analyze(squat_pose(120.0, 175.0, visibility=0.1))
    assert result.rep_count == 0
    assert result.key_angles.left_knee is None
