"""Test bảng ánh xạ tên bài tập -> analyzer.

Thư viện có 417 bài nhưng chỉ 9 analyzer, nên registry liệt kê thủ công từng
biến thể đã đối chiếu với thứ analyzer đó thật sự đo. Các test dưới đây khoá
lại những quyết định LOẠI TRỪ — phần dễ bị phá nhất, vì cách "sửa" hiển nhiên
khi thấy độ phủ thấp là đổi sang khớp chuỗi con, mà làm vậy thì người tập
nhận hướng dẫn sai trong khi app vẫn báo là đang phân tích đúng bài.
"""

import pytest

from app.ml.analyzers.bench_press import BenchPressAnalyzer
from app.ml.analyzers.calf_raise import CalfRaiseAnalyzer
from app.ml.analyzers.chest_fly import ChestFlyAnalyzer
from app.ml.analyzers.crunch import CrunchAnalyzer
from app.ml.analyzers.curl import CurlAnalyzer
from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.face_pull import FacePullAnalyzer
from app.ml.analyzers.hip_abduction import HipAbductionAnalyzer
from app.ml.analyzers.hip_adduction import HipAdductionAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.kickback import KickbackAnalyzer
from app.ml.analyzers.lateral_raise import LateralRaiseAnalyzer
from app.ml.analyzers.leg_curl import LegCurlAnalyzer
from app.ml.analyzers.leg_extension import LegExtensionAnalyzer
from app.ml.analyzers.leg_press import LegPressAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.overhead_press import OverheadPressAnalyzer
from app.ml.analyzers.pulldown import PulldownAnalyzer
from app.ml.analyzers.pullover import PulloverAnalyzer
from app.ml.analyzers.registry import (
    ANALYZER_REGISTRY,
    SINGLE_SIDE_EXERCISES,
    build_analyzer,
    supports_analysis,
)
from app.ml.analyzers.row import RowAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.analyzers.tricep_extension import TricepExtensionAnalyzer


@pytest.mark.parametrize(
    "exercise",
    [
        # Chứa "row" nhưng là bài vai kéo dọc thân, không phải kéo ngang.
        "Barbell Upright Row",
        "Dumbbell Upright Row",
        # Cardio máy chèo, không phải bài kéo tạ.
        "Rowing Machine Steady State",
        "Rowing Sprint",
        # Chứa "curl" nhưng gập một khớp khác hẳn khuỷu tay. Lying Leg Curl/
        # Nordic Hamstring Curl (gối) thuộc LegCurlAnalyzer từ 13/09/2026 —
        # không còn ở đây, xem test_bien_the_map_dung_analyzer.
        "Barbell Wrist Curl",  # cổ tay
        "Barbell Spinal Jefferson Curl",  # cột sống, không phải khuỷu tay
        "Neck Curl",  # cổ
        # Chứa "raise" nhưng gập mu bàn chân (dorsiflexion) — ngược hẳn calf
        # raise (gập lòng bàn chân).
        "Tibialis Raise",
        # Chứa "pulldown" nhưng khuỷu tay gần như khoá thẳng suốt động tác —
        # chuyển động ở vai, không phải khuỷu tay.
        "Straight Arm Lat Pulldown",
    ],
)
def test_khop_chuoi_con_khong_duoc_lot_qua(exercise: str) -> None:
    """Những tên này sẽ lọt nếu ai đó đổi sang khớp chuỗi con."""
    assert not supports_analysis(exercise)


@pytest.mark.parametrize(
    "exercise",
    [
        # CalfRaiseAnalyzer quy ước NGƯỢC (chân nghỉ giữ góc NHỎ, không phải
        # LỚN như mọi analyzer khác) — active_side() sẽ chọn nhầm chân đang
        # nghỉ. Cần thiết kế riêng, chưa làm — xem comment loại trừ trong
        # `_CALF_RAISE_VARIANTS`.
        "Dumbbell Single Leg Calf Raise",
        "Single Leg Standing Calf Raise",
        # Kickstand RDL: chân sau chỉ chạm nhẹ gần sàn giữ thăng bằng, KHÔNG
        # duỗi thẳng ra sau thành một đường như single-leg RDL "chuẩn" (đã
        # CHUYỂN sang single_side=True — xem SINGLE_SIDE_EXERCISES trong
        # registry.py, CHANGELOG 13/09/2026) — góc phía chân kiềng không chắc
        # giữ ổn định vùng góc lớn suốt bài, active_side() có thể chọn nhầm.
        "Kickstand Dumbbell Romanian Deadlift",
        # Có xoay thân (tay chéo sang chân đối diện) — góc vai-hông-gối đọc
        # sai khi thân xoay, thuộc giới hạn chung "không đo được xoay quanh
        # trục dọc" của cả dự án, không liên quan single_side.
        "Dumbbell Cross Body Romanian Deadlift",
    ],
)
def test_bai_mot_ben_hinh_hoc_khac_van_bi_loai(exercise: str) -> None:
    """Bài một bên có hình học/quy ước góc khác biệt thật sự (không chỉ vấn
    đề avg() hai bên) vẫn bị loại — xem SINGLE_SIDE_EXERCISES cho các bài
    một bên ĐÃ hỗ trợ được bằng active_side()."""
    assert not supports_analysis(exercise)


@pytest.mark.parametrize(
    "exercise",
    [
        "Bodyweight Alternating Lateral Lunge",  # bước sang ngang
        "Dumbbell Goblet Alternating Curtsy Lunge",  # bước chéo ra sau
        "Cossack Squat",  # squat sang ngang
        "Elbow Side Plank",  # nằm nghiêng
        "Sissy Squat",  # cố ý đẩy gối vượt xa mũi chân
    ],
)
def test_bai_khac_mat_phang_chuyen_dong_bi_loai(exercise: str) -> None:
    assert not supports_analysis(exercise)


@pytest.mark.parametrize(
    ("exercise", "expected"),
    [
        ("Barbell Squat", SquatAnalyzer),
        ("Dumbbell Goblet Squat", SquatAnalyzer),
        ("Barbell Bent Over Row", RowAnalyzer),
        ("Machine Seated Cable Row", RowAnalyzer),
        ("Barbell Incline Bench Press", BenchPressAnalyzer),
        ("Barbell Romanian Deadlift", DeadliftAnalyzer),
        ("Barbell Reverse Lunge", LungeAnalyzer),
        # Đứng so le -> Lunge chứ KHÔNG phải Squat: squat lấy trung bình hai
        # gối, lunge lấy min() nên đọc đúng chân trước.
        ("Bulgarian Split Squat", LungeAnalyzer),
        ("Barbell Split Squat", LungeAnalyzer),
        ("Barbell Curl", CurlAnalyzer),
        ("Dumbbell Hammer Curl", CurlAnalyzer),
        ("Ez Bar Preacher Curl", CurlAnalyzer),
        ("Dumbbell Lateral Raise", LateralRaiseAnalyzer),
        ("Dumbbell Rear Delt Fly", LateralRaiseAnalyzer),
        ("Dumbbell Chest Fly", ChestFlyAnalyzer),
        ("Kettlebell Calf Raise", CalfRaiseAnalyzer),
        ("Push Up", BenchPressAnalyzer),
        ("Bench Dips", BenchPressAnalyzer),
        ("Glute Bridge", HipThrustAnalyzer),
        ("Good Mornings", DeadliftAnalyzer),
        ("Reverse Pec Deck", LateralRaiseAnalyzer),
        ("Machine Leg Extension", LegExtensionAnalyzer),
        ("Cable Bar Pushdown", TricepExtensionAnalyzer),
        ("Lat Pulldown", PulldownAnalyzer),
        ("Pull Ups", PulldownAnalyzer),
        # Thêm 13/09/2026, rà tay checklist 412 bài (xem CHANGELOG) — biến
        # thể khác nhóm đứng/ngồi/xoay cổ tay/có đà chân nhưng cùng cơ chế
        # góc khuỷu tay của analyzer gốc.
        ("Narrow Pulldown", PulldownAnalyzer),
        ("Cable Rope Pushdown", TricepExtensionAnalyzer),
        ("Cable Pull Through", DeadliftAnalyzer),
        ("Arnold Press", OverheadPressAnalyzer),
        ("Behind The Neck Press", OverheadPressAnalyzer),
        ("Dumbbell Push Press", OverheadPressAnalyzer),
        ("Kettlebell Push Press", OverheadPressAnalyzer),
        ("Landmine Press", OverheadPressAnalyzer),
        ("Machine Front Military Press", OverheadPressAnalyzer),
        ("Z Press", OverheadPressAnalyzer),
        # Thêm 13/09/2026 — bài một tay/một chân, single_side=True (xem
        # SINGLE_SIDE_EXERCISES trong registry.py và test hành vi riêng ở
        # test_single_side_dem_rep_dung.py).
        ("Dumbbell Single Arm Row", RowAnalyzer),
        ("Dumbbell Row Unilateral", RowAnalyzer),
        ("Meadows Row", RowAnalyzer),
        ("Single Leg Hip Thrust", HipThrustAnalyzer),
        ("B Stance Hip Thrust", HipThrustAnalyzer),
        ("Single Arm Dumbbell Overhead Press", OverheadPressAnalyzer),
        ("Dumbbell Standing Single Arm Curl", CurlAnalyzer),
        ("Dumbbell Concentration Curl", CurlAnalyzer),
        ("Bayesian Curl", CurlAnalyzer),
        ("Band Single Arm Lateral Raise", LateralRaiseAnalyzer),
        ("Leaning Cable Lateral Raise", LateralRaiseAnalyzer),
        ("Single Arm Cable Fly", ChestFlyAnalyzer),
        ("Dumbbell Single Arm Chest Press", BenchPressAnalyzer),
        ("Cable Standing Single Arm Chest Press", BenchPressAnalyzer),
        ("Single Arm Overhead Cable Extension", TricepExtensionAnalyzer),
        ("Single Arm Tricep Extension", TricepExtensionAnalyzer),
        ("Single Arm Lat Pulldown", PulldownAnalyzer),
        # Thêm 13/09/2026 — 3 analyzer MỚI (LegCurl/Pullover/LegPress), xem
        # CHANGELOG cho lý do từng bài.
        ("Lying Leg Curl", LegCurlAnalyzer),
        ("Nordic Hamstring Curl", LegCurlAnalyzer),
        ("Cable Single Leg Laying Leg Curl", LegCurlAnalyzer),
        ("Band Pullover", PulloverAnalyzer),
        ("Machine Lat Pullover", PulloverAnalyzer),
        ("Machine Leg Press", LegPressAnalyzer),
        ("Machine Horizontal Leg Press", LegPressAnalyzer),
        ("Decline Sit Up", CrunchAnalyzer),
        ("Hanging Knee Raises", CrunchAnalyzer),
        ("Machine Face Pulls", FacePullAnalyzer),
        ("Standing Cable Hip Abduction", HipAbductionAnalyzer),
        ("Machine Hip Abduction", HipAbductionAnalyzer),
        # Thêm 13/09/2026 (đợt 2) — rà nốt Nhóm C (single-leg RDL) và 2
        # analyzer MỚI (HipAdduction/Kickback), xem CHANGELOG cho lý do
        # từng bài.
        ("Single Leg Dumbbell Romanian Deadlift", DeadliftAnalyzer),
        ("Single Leg Kettlebell Romanian Deadlift Deficit", DeadliftAnalyzer),
        ("Single Legged Romanian Deadlifts", DeadliftAnalyzer),
        ("Machine Hip Adduction", HipAdductionAnalyzer),
        ("Cable Bench Straight Leg Kickback", KickbackAnalyzer),
        ("Cable Kickback", KickbackAnalyzer),
        ("Glute Kickback Machine", KickbackAnalyzer),
    ],
)
def test_bien_the_map_dung_analyzer(exercise: str, expected: type) -> None:
    assert supports_analysis(exercise)
    assert ANALYZER_REGISTRY[exercise.lower()] is expected


def test_tra_ten_khong_phan_biet_hoa_thuong() -> None:
    """Tên trong DB viết hoa đầu từ, key trong registry viết thường."""
    assert supports_analysis("BARBELL SQUAT")
    assert supports_analysis("barbell squat")


def test_key_deu_viet_thuong() -> None:
    """Key viết hoa sẽ không bao giờ tra tới được vì hàm tra đã hạ chữ."""
    assert all(k == k.lower() for k in ANALYZER_REGISTRY)


def test_build_analyzer_bat_single_side_dung_bai() -> None:
    """`build_analyzer()` chỉ bật single_side cho tên nằm trong
    SINGLE_SIDE_EXERCISES, không ảnh hưởng bài thường cùng analyzer."""
    single_side_analyzer = build_analyzer("Dumbbell Single Arm Row", RowAnalyzer)
    assert single_side_analyzer._single_side is True  # noqa: SLF001

    normal_analyzer = build_analyzer("Barbell Bent Over Row", RowAnalyzer)
    assert normal_analyzer._single_side is False  # noqa: SLF001


def test_single_side_exercises_deu_hop_le() -> None:
    """Mọi tên trong SINGLE_SIDE_EXERCISES phải tra ra analyzer THẬT SỰ hỗ
    trợ single_side — self-check này đã chạy lúc import registry.py, test ở
    đây chỉ để lỗi (nếu có trong tương lai) hiện ra như một test đỏ rõ ràng
    thay vì một AssertionError lúc import khó truy vết."""
    for name in SINGLE_SIDE_EXERCISES:
        cls = ANALYZER_REGISTRY[name]
        assert getattr(cls, "SUPPORTS_SINGLE_SIDE", False) is True
