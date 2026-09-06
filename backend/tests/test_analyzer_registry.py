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
from app.ml.analyzers.curl import CurlAnalyzer
from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.lateral_raise import LateralRaiseAnalyzer
from app.ml.analyzers.leg_extension import LegExtensionAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.registry import ANALYZER_REGISTRY, supports_analysis
from app.ml.analyzers.row import RowAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.analyzers.tricep_extension import TricepExtensionAnalyzer


@pytest.mark.parametrize(
    "exercise",
    [
        # Chứa "row" nhưng là bài vai kéo dọc thân, không phải kéo ngang.
        "Barbell Upright Row",
        "Dumbbell Upright Row",
        # "Nar-row" — trùng chuỗi thuần tuý, không liên quan động tác row.
        "Narrow Pulldown",
        # Cardio máy chèo, không phải bài kéo tạ.
        "Rowing Machine Steady State",
        "Rowing Sprint",
        # Chứa "curl" nhưng gập một khớp khác hẳn khuỷu tay.
        "Lying Leg Curl",  # gối (hamstring)
        "Nordic Hamstring Curl",  # gối (hamstring)
        "Barbell Wrist Curl",  # cổ tay
        "Barbell Spinal Jefferson Curl",  # cột sống, không phải khuỷu tay
        "Neck Curl",  # cổ
        # Chứa "raise" nhưng gập mu bàn chân (dorsiflexion) — ngược hẳn calf
        # raise (gập lòng bàn chân).
        "Tibialis Raise",
    ],
)
def test_khop_chuoi_con_khong_duoc_lot_qua(exercise: str) -> None:
    """Những tên này sẽ lọt nếu ai đó đổi sang khớp chuỗi con."""
    assert not supports_analysis(exercise)


@pytest.mark.parametrize(
    "exercise",
    [
        # RowAnalyzer lấy avg() góc hai khuỷu tay: tay rảnh giữ ~170° kéo
        # trung bình lên, không bao giờ chạm ngưỡng co 70° -> rep không đếm
        # được và app báo "kéo tạ chưa hết" suốt buổi.
        "Dumbbell Single Arm Row",
        "Dumbbell Row Unilateral",
        "Meadows Row",
        # HipThrustAnalyzer báo lỗi khi hai hông lệch > 15°.
        "Single Leg Hip Thrust",
        "B Stance Hip Thrust",
        # OverheadPressAnalyzer báo lỗi khi hai tay lệch > 25°.
        "Single Arm Dumbbell Overhead Press",
        # DeadliftAnalyzer đọc góc hông hai chân.
        "Single Leg Dumbbell Romanian Deadlift",
        # CurlAnalyzer lấy avg() hai khuỷu tay giống RowAnalyzer.
        "Dumbbell Standing Single Arm Curl",
        "Dumbbell Concentration Curl",  # luôn một tay theo định nghĩa
        "Bayesian Curl",  # cable sau lưng, gần như luôn một tay
        # LateralRaiseAnalyzer/ChestFlyAnalyzer cũng lấy avg() hai vai.
        "Band Single Arm Lateral Raise",
        "Leaning Cable Lateral Raise",  # đứng nghiêng người, luôn một tay
        "Single Arm Cable Fly",
        # CalfRaiseAnalyzer cũng lấy avg() hai mắt cá.
        "Dumbbell Single Leg Calf Raise",
        "Single Leg Standing Calf Raise",
        # BenchPressAnalyzer cũng vậy (push-up/dip/chest press một tay).
        "Dumbbell Single Arm Chest Press",
        "Cable Standing Single Arm Chest Press",
        # TricepExtensionAnalyzer cũng vậy.
        "Single Arm Overhead Cable Extension",
        "Single Arm Tricep Extension",
    ],
)
def test_bai_mot_ben_bi_loai(exercise: str) -> None:
    """Analyzer gộp hoặc so hai bên nên bài một bên luôn cho kết quả sai."""
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
