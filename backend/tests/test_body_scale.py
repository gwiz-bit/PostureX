"""Kết quả phân tích phải KHÔNG phụ thuộc người to/nhỏ, đứng gần/xa camera, khung ngang/dọc.

Phát hiện 01/10/2026 (mô phỏng qua chính analyzer): đếm rep theo góc thì bất biến theo
kích thước người, nhưng ngưỡng "gối vượt mũi chân" từng cố định theo CHIỀU RỘNG KHUNG
(0,05) nên cùng một lỗi kỹ thuật bị báo khi gối vượt chỉ 10% chiều dài chân (người to/
gần) nhưng phải vượt tới 31% (người nhỏ/xa). Test này khoá lại để không ai vô tình làm
hỏng tính bất biến đó — mọi kiểm tra mới dựa trên toạ độ phải đo theo thân người, không
theo khung hình.

Phóng/thu người bằng cách co giãn mọi khớp quanh điểm chân (giống đứng gần/xa camera).
"""

import random
import statistics

import pytest

from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.angle_utils import calculate_angle_3d
from app.ml.pose_estimator import Keypoint
from tests.pose_builders import (
    LEFT_ANKLE,
    LEFT_FOOT_INDEX,
    LEFT_HIP,
    LEFT_KNEE,
    RIGHT_ANKLE,
    RIGHT_FOOT_INDEX,
    RIGHT_HIP,
    RIGHT_KNEE,
    hinge_pose,
    squat_pose,
)
from tests.test_analyzers import rep_sequence

# 1,0 = người có chân (hông → cổ chân) dài ~1/3 chiều cao khung.
SCALES = [0.5, 0.7, 1.0, 1.3, 1.6]


def scale_pose(pose: list[Keypoint], s: float, cx: float = 0.5, cy: float = 0.95) -> list[Keypoint]:
    return [
        Keypoint(
            x=cx + s * (k.x - cx),
            y=cy + s * (k.y - cy),
            z=k.z,
            visibility=k.visibility,
            aspect=k.aspect,
        )
        for k in pose
    ]


def _leg_length(pose: list[Keypoint]) -> float:
    hip, ankle = pose[LEFT_HIP], pose[LEFT_ANKLE]
    return ((hip.x - ankle.x) ** 2 + (hip.y - ankle.y) ** 2) ** 0.5


def _with_knee_past_toe(pose: list[Keypoint], fraction_of_leg: float) -> list[Keypoint]:
    """Đặt mũi chân TRÁI sao cho gối vượt mũi chân đúng `fraction_of_leg` × chiều dài chân."""
    pose = list(pose)
    knee, foot = pose[LEFT_KNEE], pose[LEFT_FOOT_INDEX]
    pose[LEFT_FOOT_INDEX] = Keypoint(
        x=knee.x - fraction_of_leg * _leg_length(pose), y=foot.y, z=0.0, visibility=1.0, aspect=knee.aspect
    )
    return pose


def _flagged(analyzer, pose: list[Keypoint]) -> bool:
    return any("vượt quá mũi chân" in e for e in analyzer.analyze(pose).errors)


# ─────────────────────────────────────────────────────────────────────
# Đếm rep và lỗi không đổi theo kích thước người
# ─────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("s", SCALES)
def test_squat_hoan_hao_dem_dung_mot_rep_moi_kich_thuoc(s: float) -> None:
    analyzer = SquatAnalyzer()
    errors: set[str] = set()
    for angle in rep_sequence(170, 85):
        errors.update(analyzer.analyze(scale_pose(squat_pose(angle, 175.0), s)).errors)

    assert analyzer.rep_counter.rep_count == 1
    assert errors == set()


@pytest.mark.parametrize("s", SCALES)
def test_deadlift_hoan_hao_dem_dung_mot_rep_moi_kich_thuoc(s: float) -> None:
    analyzer = DeadliftAnalyzer()
    errors: set[str] = set()
    for angle in rep_sequence(170, 90):
        errors.update(analyzer.analyze(scale_pose(hinge_pose(angle), s)).errors)

    assert analyzer.rep_counter.rep_count == 1
    assert errors == set()


# ─────────────────────────────────────────────────────────────────────
# "Gối vượt mũi chân" đo theo chiều dài chân, không theo khung hình
# ─────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize("s", SCALES)
@pytest.mark.parametrize(
    ("analyzer_cls", "make_pose"),
    [
        (SquatAnalyzer, lambda: squat_pose(120.0, 175.0)),
        (LungeAnalyzer, lambda: squat_pose(120.0, 175.0)),
        (DeadliftAnalyzer, lambda: hinge_pose(140.0)),
    ],
)
def test_goi_vuot_nhieu_duoc_bao_moi_kich_thuoc(analyzer_cls, make_pose, s: float) -> None:
    """Vượt 25% chiều dài chân (hơn hẳn ngưỡng 15%) phải bị báo dù người to hay nhỏ."""
    pose = _with_knee_past_toe(scale_pose(make_pose(), s), 0.25)
    assert _flagged(analyzer_cls(), pose)


@pytest.mark.parametrize("s", SCALES)
@pytest.mark.parametrize(
    ("analyzer_cls", "make_pose"),
    [
        (SquatAnalyzer, lambda: squat_pose(120.0, 175.0)),
        (LungeAnalyzer, lambda: squat_pose(120.0, 175.0)),
        (DeadliftAnalyzer, lambda: hinge_pose(140.0)),
    ],
)
def test_goi_vuot_nhe_khong_bi_bao_oan_moi_kich_thuoc(analyzer_cls, make_pose, s: float) -> None:
    """Vượt 12% chiều dài chân (dưới ngưỡng 15%) KHÔNG được báo — kể cả người to/gần.

    Đây đúng là ca từng sai: với ngưỡng cố định theo khung hình, người chiếm nhiều khung
    (s = 1,3 đến 1,6) bị báo khi chỉ vượt ~10-12% chiều dài chân. Mức 12% được chọn NẰM GIỮA
    hai ngưỡng (cũ ~10% ở người to, mới 15%) nên test này đỏ trên code cũ."""
    pose = _with_knee_past_toe(scale_pose(make_pose(), s), 0.12)
    assert not _flagged(analyzer_cls(), pose)


def test_nguong_goi_vuot_dung_cho_ca_chan_phai() -> None:
    """Chân phải đối xứng: mũi chân ở bên −x của gối."""
    pose = squat_pose(120.0, 175.0)
    knee, foot = pose[RIGHT_KNEE], pose[RIGHT_FOOT_INDEX]
    leg = (
        (pose[RIGHT_HIP].x - pose[RIGHT_ANKLE].x) ** 2 + (pose[RIGHT_HIP].y - pose[RIGHT_ANKLE].y) ** 2
    ) ** 0.5

    def with_overshoot(fraction: float) -> list[Keypoint]:
        p = list(pose)
        p[RIGHT_FOOT_INDEX] = Keypoint(x=knee.x + fraction * leg, y=foot.y, z=0.0, visibility=1.0)
        return p

    assert _flagged(SquatAnalyzer(), with_overshoot(0.25))
    assert not _flagged(SquatAnalyzer(), with_overshoot(0.05))


# ─────────────────────────────────────────────────────────────────────
# Không phụ thuộc khung hình dọc/ngang
# ─────────────────────────────────────────────────────────────────────


@pytest.mark.parametrize(("width", "height"), [(480, 720), (720, 1280), (640, 480), (1280, 720), (600, 600)])
@pytest.mark.parametrize(("fraction", "expected"), [(0.20, True), (0.12, False)])
def test_goi_vuot_khong_phu_thuoc_ti_le_khung(width: int, height: int, fraction: float, expected: bool) -> None:
    """Cùng một hình học trên màn hình (pixel), chuẩn hoá theo khung khác nhau → cùng kết luận.

    Nếu quên nhân `aspect` cho x, khung dọc (x bị nén) sẽ thấy gối vượt ít hơn thật."""
    base = _with_knee_past_toe(squat_pose(120.0, 175.0), fraction)
    # Coi `base` là hình học pixel trong khung vuông 1000x1000, rồi chuẩn hoá lại theo
    # khung (width x height) — đúng cách MediaPipe/ML Kit chuẩn hoá x/W, y/H.
    pose = [
        Keypoint(
            x=k.x * 1000 / width,
            y=k.y * 1000 / height,
            z=0.0,
            visibility=1.0,
            aspect=width / height,
        )
        for k in base
    ]
    assert _flagged(SquatAnalyzer(), pose) is expected


# ─────────────────────────────────────────────────────────────────────
# Nhiễu khớp phụ thuộc kích thước (tính chất của phép đo, không phải lỗi)
# ─────────────────────────────────────────────────────────────────────


def _angle_std(s: float, sigma: float = 0.004, n: int = 1500) -> float:
    rng = random.Random(7)
    base = scale_pose(squat_pose(100.0, 175.0), s)
    readings = []
    for _ in range(n):
        noisy = [
            Keypoint(x=k.x + rng.gauss(0, sigma), y=k.y + rng.gauss(0, sigma), z=0.0, visibility=1.0) for k in base
        ]
        readings.append(calculate_angle_3d(noisy[LEFT_HIP], noisy[LEFT_KNEE], noisy[LEFT_ANKLE]))
    return statistics.pstdev(readings)


def test_nguoi_nho_trong_khung_bi_nhieu_goc_lon_hon() -> None:
    """Nhiễu góc tỉ lệ nghịch với kích thước người trong khung (cùng nhiễu điểm ảnh).

    Đây là lý do có cảnh báo 'hãy đứng gần camera hơn' phía app: người chiếm ít khung thì
    góc dao động mạnh, dễ đếm hụt/thừa rep. Test khoá tính chất để nếu ai đó làm mượt lại
    bộ lọc mà vô tình đổi nó thì có tín hiệu."""
    nho = _angle_std(0.5)
    to = _angle_std(1.6)
    assert nho > 2.0 * to
