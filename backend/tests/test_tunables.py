"""Test bảng ngưỡng chỉnh được (`app/ml/analyzers/tunables.py`).

Bảng này là siêu dữ liệu thuần, nhưng sai ở đây hỏng theo kiểu IM LẶNG — đó
là lý do phải có test riêng thay vì tin vào việc đọc lại code:

  - Khai một khoá không có trong `VALUE_COLUMN`: ngưỡng vẫn được ghi xuống DB
    bình thường, rồi `load_thresholds` bỏ qua lúc chạy. Admin chỉnh, bấm Lưu,
    thấy báo thành công, và không có gì đổi.
  - Khai `default` khác hằng số thật trong analyzer: màn admin hiện một con số,
    analyzer chạy bằng con số khác. Không ai phát hiện cho tới khi có người
    đối chiếu tay.
  - Bỏ sót một analyzer: bài thuộc analyzer đó không chỉnh được, mà cũng không
    có lỗi nào — nó chỉ đơn giản là không hiện ô nào.
"""

import pytest

from app.ml.analyzers import (
    bench_press,
    cat_cow,
    deadlift,
    hip_thrust,
    lunge,
    overhead_press,
    plank,
    row,
    squat,
)
from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.ml.analyzers.thresholds import VALUE_COLUMN
from app.ml.analyzers.tunables import (
    MIN_REP_RANGE,
    ORDERED_PAIRS,
    TUNABLES,
    tunables_for,
    validate,
)

# ─────────────────────────────────────────────────────────────────────
# Tính toàn vẹn của bảng
# ─────────────────────────────────────────────────────────────────────

def test_phu_du_ca_9_analyzer() -> None:
    """Thiếu một analyzer nghĩa là mọi bài của nó không chỉnh được gì."""
    trong_registry = {cls.__name__ for cls in ANALYZER_REGISTRY.values()}

    assert trong_registry == set(TUNABLES), (
        f"Lệch: registry có {sorted(trong_registry - set(TUNABLES))}, "
        f"bảng có thừa {sorted(set(TUNABLES) - trong_registry)}"
    )


def test_moi_khoa_deu_co_trong_value_column() -> None:
    """Khoá lạ bị bỏ qua trong im lặng lúc chạy — phải chặn từ đây.

    Chính module `tunables` cũng tự kiểm điều này lúc import và ném
    RuntimeError; test lặp lại để lỗi hiện ra dưới dạng test đỏ có tên rõ ràng
    thay vì cả bộ test sập vì lỗi import.
    """
    khoa = {t.key for group in TUNABLES.values() for t in group}

    assert khoa <= set(VALUE_COLUMN), f"Khoá lạ: {sorted(khoa - set(VALUE_COLUMN))}"


def test_khong_khai_trung_khoa_trong_cung_analyzer() -> None:
    """Trùng khoá thì giao diện hiện hai ô cho cùng một giá trị.

    Đúng cái bẫy của màn hình cũ: `squat_knee_depth_threshold` và
    `squat_rep_down_threshold` vốn là một số, nhưng lộ ra thành hai thanh
    trượt — kéo thanh này không ảnh hưởng thanh kia, nên admin không thể đoán
    được cái nào đang có tác dụng.
    """
    for ten, group in TUNABLES.items():
        khoa = [t.key for t in group]
        assert len(khoa) == len(set(khoa)), f"{ten} khai trùng khoá: {khoa}"


def test_mac_dinh_nam_trong_khoang_hop_le() -> None:
    """Mặc định ngoài khoảng thì admin mở màn hình ra đã thấy giá trị đỏ."""
    for ten, group in TUNABLES.items():
        for t in group:
            assert t.minimum <= t.default <= t.maximum, (
                f"{ten}.{t.key}: mặc định {t.default} ngoài khoảng "
                f"{t.minimum}–{t.maximum}"
            )
            assert t.minimum < t.maximum, f"{ten}.{t.key}: khoảng rỗng"


def test_moi_tunable_co_nhan_tieng_viet() -> None:
    """Nhãn là thứ admin đọc để biết mình đang chỉnh gì — không được để trống."""
    for ten, group in TUNABLES.items():
        for t in group:
            assert t.label.strip(), f"{ten}.{t.key} thiếu nhãn"
            assert len(t.label) > 10, f"{ten}.{t.key} nhãn quá ngắn: {t.label!r}"


# ─────────────────────────────────────────────────────────────────────
# Mặc định phải khớp hằng số thật trong analyzer
# ─────────────────────────────────────────────────────────────────────
#
# Đây là test đáng giá nhất file này. Hai nguồn số này nằm ở hai file khác
# nhau và không có gì buộc chúng khớp nhau; lệch đi thì màn admin hiển thị
# một con số còn analyzer chạy bằng con số khác — sai theo kiểu không ai
# nhìn ra, vì cả hai bên đều "chạy bình thường".

@pytest.mark.parametrize(
    ("analyzer_name", "key", "hang_so_that"),
    [
        ("SquatAnalyzer", "knee_depth", squat.KNEE_DEPTH_THRESHOLD),
        ("SquatAnalyzer", "back_straight_min", squat.BACK_STRAIGHT_MIN),
        ("LungeAnalyzer", "knee_depth", lunge.KNEE_DEPTH_THRESHOLD),
        ("LungeAnalyzer", "back_straight_min", lunge.BACK_STRAIGHT_MIN),
        ("RowAnalyzer", "elbow_contracted", row.ELBOW_CONTRACTED_THRESHOLD),
        ("RowAnalyzer", "elbow_extended", row.ELBOW_EXTENDED_THRESHOLD),
        ("RowAnalyzer", "back_straight_min", row.BACK_STRAIGHT_MIN),
        ("BenchPressAnalyzer", "elbow_down", bench_press.ELBOW_DOWN_THRESHOLD),
        ("BenchPressAnalyzer", "elbow_lockout", bench_press.ELBOW_LOCKOUT_THRESHOLD),
        ("BenchPressAnalyzer", "elbow_asymmetry", bench_press.ELBOW_ASYMMETRY_THRESHOLD),
        ("OverheadPressAnalyzer", "elbow_down", overhead_press.ELBOW_DOWN_THRESHOLD),
        ("OverheadPressAnalyzer", "elbow_lockout", overhead_press.ELBOW_LOCKOUT_THRESHOLD),
        ("OverheadPressAnalyzer", "elbow_asymmetry", overhead_press.ELBOW_ASYMMETRY_THRESHOLD),
        ("DeadliftAnalyzer", "hip_down", deadlift.HIP_HINGE_DOWN_THRESHOLD),
        ("DeadliftAnalyzer", "hip_up", deadlift.HIP_HINGE_UP_THRESHOLD),
        ("HipThrustAnalyzer", "hip_down", hip_thrust.HIP_DOWN_THRESHOLD),
        ("HipThrustAnalyzer", "hip_up", hip_thrust.HIP_UP_THRESHOLD),
        ("HipThrustAnalyzer", "hip_asymmetry", hip_thrust.HIP_ASYMMETRY_THRESHOLD),
        ("PlankAnalyzer", "straight_body_min", plank.STRAIGHT_BODY_MIN),
        ("PlankAnalyzer", "hip_sag", plank.HIP_SAG_THRESHOLD),
        ("CatCowAnalyzer", "cat", cat_cow.CAT_THRESHOLD),
        ("CatCowAnalyzer", "cow", cat_cow.COW_THRESHOLD),
    ],
)
def test_mac_dinh_khop_hang_so_analyzer(analyzer_name: str, key: str, hang_so_that: float) -> None:
    khai_bao = next(t for t in tunables_for(analyzer_name) if t.key == key)

    assert khai_bao.default == hang_so_that, (
        f"{analyzer_name}.{key}: bảng khai {khai_bao.default}, "
        f"analyzer dùng {hang_so_that}"
    )


def test_stand_up_min_khop_gia_tri_inline() -> None:
    """`stand_up_min` không có hằng số module — nó nằm inline trong `__init__`.

    Squat dùng 155° (không phải 160° như tên gọi gợi ý) vì nhiều người không
    duỗi thẳng hết gối khi đứng; lunge dùng 160°. Đọc ngược từ RepCounter mà
    analyzer tự dựng, thay vì chép tay con số vào đây rồi để nó lệch đi.
    """
    assert tunables_for("SquatAnalyzer")[1].key == "stand_up_min"
    assert tunables_for("SquatAnalyzer")[1].default == squat.SquatAnalyzer().rep_counter.up_threshold
    assert tunables_for("LungeAnalyzer")[1].default == lunge.LungeAnalyzer().rep_counter.up_threshold


# ─────────────────────────────────────────────────────────────────────
# Kiểm giá trị admin nhập
# ─────────────────────────────────────────────────────────────────────

def test_gia_tri_hop_le_khong_bao_loi() -> None:
    assert validate("SquatAnalyzer", {"knee_depth": 90.0, "back_straight_min": 145.0}) == []


def test_de_trong_cung_hop_le() -> None:
    """Gửi `{}` nghĩa là bỏ hết ghi đè, quay về mặc định — không phải lỗi."""
    assert validate("SquatAnalyzer", {}) == []


def test_khoa_khong_thuoc_analyzer_bi_tu_choi() -> None:
    """`hip_sag` là của plank; gán cho squat thì sẽ bị bỏ qua lúc chạy."""
    loi = validate("SquatAnalyzer", {"hip_sag": 150.0})

    assert len(loi) == 1
    assert "hip_sag" in loi[0]


def test_gia_tri_ngoai_khoang_bi_tu_choi() -> None:
    loi = validate("SquatAnalyzer", {"knee_depth": 300.0})

    assert len(loi) == 1
    assert "40" in loi[0] and "140" in loi[0]


def test_bao_tat_ca_loi_khoang_mot_luot() -> None:
    """Dừng ở lỗi đầu tiên thì admin phải bấm Lưu nhiều lần mới biết hết."""
    loi = validate("SquatAnalyzer", {"knee_depth": 999.0, "back_straight_min": -5.0})

    assert len(loi) == 2


def test_loi_khoang_khong_keo_theo_loi_thu_tu_nham() -> None:
    """Giá trị đã bị từ chối không được đem đi so thứ tự.

    `knee_depth=999` vượt khoảng. Nếu vẫn đem 999 đi kiểm cặp thì sinh thêm
    "ngưỡng đứng thẳng 155° phải lớn hơn ngưỡng chạm đáy 999°" — đọc như thể
    155 mới là chỗ sai, và admin đi sửa nhầm ô. Chỉ được báo đúng một lỗi.
    """
    loi = validate("SquatAnalyzer", {"knee_depth": 999.0})

    assert len(loi) == 1
    assert "bộ đếm rep" not in loi[0]


# ─────────────────────────────────────────────────────────────────────
# Thứ tự cặp ngưỡng đếm rep — phần dễ hỏng nhất
# ─────────────────────────────────────────────────────────────────────

def test_dao_thu_tu_bi_tu_choi() -> None:
    """Ngưỡng "đứng thẳng" thấp hơn ngưỡng "chạm đáy" là điều kiện không bao
    giờ thoả — RepCounter đứng im ở 0 mà không báo lỗi gì."""
    loi = validate("DeadliftAnalyzer", {"hip_down": 140.0, "hip_up": 130.0})

    assert len(loi) == 1
    assert "bộ đếm rep không hoạt động" in loi[0]


def test_qua_gan_nhau_bi_tu_choi() -> None:
    """Hai ngưỡng cách nhau dưới biên dung sai 10° của RepCounter thì vùng
    "đáy" và vùng "đã đứng thẳng" chồng lên nhau."""
    loi = validate("DeadliftAnalyzer", {"hip_down": 130.0, "hip_up": 140.0})

    assert len(loi) == 1
    assert f"{MIN_REP_RANGE:g}" in loi[0]


def test_kiem_tren_gia_tri_co_hieu_luc_khong_chi_phan_vua_nhap() -> None:
    """Cái bẫy: chỉ sửa MỘT vế của cặp.

    Admin hạ `hip_up` xuống 120° mà không đụng `hip_down` (mặc định 110°) —
    phần gửi lên chỉ có một khoá nên nhìn qua thì "không có cặp nào để kiểm".
    Nhưng giá trị có hiệu lực là cặp (110, 120), cách nhau 10° < 15°, đủ để
    làm hỏng bộ đếm. Kiểm phải trộn cái nhập với mặc định mới bắt được.
    """
    loi = validate("DeadliftAnalyzer", {"hip_up": 120.0})

    assert len(loi) == 1
    assert "bộ đếm rep" in loi[0]


def test_moi_cap_thu_tu_deu_thuoc_cung_mot_analyzer() -> None:
    """Cặp mà hai khoá không bao giờ xuất hiện cùng nhau là luật chết.

    Nó trông như đang bảo vệ điều gì đó nhưng không bao giờ chạy — kiểu mã
    chết khó thấy nhất, vì test cho nó vẫn xanh.
    """
    for lower, upper in ORDERED_PAIRS:
        co_ca_hai = [
            ten for ten, group in TUNABLES.items()
            if {lower, upper} <= {t.key for t in group}
        ]
        assert co_ca_hai, f"Cặp ({lower}, {upper}) không analyzer nào dùng cả hai"


def test_moi_analyzer_dem_rep_deu_co_cap_thu_tu_bao_ve() -> None:
    """Analyzer có ngưỡng đếm rep mà không có cặp nào canh thứ tự thì admin
    vẫn đảo ngược được chúng và làm chết bộ đếm."""
    for ten, group in TUNABLES.items():
        khoa_dem_rep = {t.key for t in group if t.affects_rep_count}
        if not khoa_dem_rep:
            continue
        duoc_bao_ve = any(
            {lower, upper} <= khoa_dem_rep for lower, upper in ORDERED_PAIRS
        )
        assert duoc_bao_ve, f"{ten} có ngưỡng đếm rep {khoa_dem_rep} nhưng không cặp nào canh"


# ─────────────────────────────────────────────────────────────────────
# `knee_overshoot` — khoá duy nhất không phải góc
# ─────────────────────────────────────────────────────────────────────

def test_knee_overshoot_khai_dung_don_vi_va_buoc() -> None:
    """Ngưỡng này là tỉ lệ theo chiều rộng khung hình, không phải độ.

    Dùng chung đơn vị "°" và bước 1.0 như các ngưỡng góc sẽ cho một thanh
    trượt vô dụng: khoảng hợp lệ chỉ 0–0.3, bước 1.0 nghĩa là chỉ nhảy được
    giữa 0 và 1 — không chọn được giá trị nào có nghĩa.
    """
    for analyzer in ("SquatAnalyzer", "LungeAnalyzer", "DeadliftAnalyzer"):
        t = next(x for x in tunables_for(analyzer) if x.key == "knee_overshoot")
        assert t.unit == "", f"{analyzer}: không được gắn đơn vị độ cho một tỉ lệ"
        assert t.step == 0.01
        assert t.default == 0.05


def test_moi_nguong_goc_van_dung_don_vi_do() -> None:
    for ten, group in TUNABLES.items():
        for t in group:
            if t.key == "knee_overshoot":
                continue
            assert t.unit == "°", f"{ten}.{t.key} thiếu đơn vị độ"
            assert t.step == 1.0


def test_buoc_nhay_chia_het_khoang_hop_le() -> None:
    """Bước không chia hết khoảng thì thanh trượt không chạm được tới biên trên.

    Admin kéo hết cỡ vẫn không đặt được giá trị lớn nhất mà chính backend cho
    phép — và không có gì trên màn hình giải thích vì sao.
    """
    for ten, group in TUNABLES.items():
        for t in group:
            so_buoc = (t.maximum - t.minimum) / t.step
            assert abs(so_buoc - round(so_buoc)) < 1e-9, (
                f"{ten}.{t.key}: khoảng {t.minimum}–{t.maximum} không chia hết "
                f"cho bước {t.step}"
            )


def test_knee_overshoot_khong_nam_trong_cap_thu_tu() -> None:
    """Nó không phải một đầu của rep nào — ràng buộc thứ tự không áp cho nó."""
    trong_cap = {k for pair in ORDERED_PAIRS for k in pair}

    assert "knee_overshoot" not in trong_cap
