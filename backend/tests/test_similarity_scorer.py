"""Test `app/ml/similarity_scorer.py` — chấm điểm "độ giống bài mẫu"."""

import pytest

from app.ml import reference_library
from app.ml.analyzers.reference_joints import DEFAULT_JOINTS, PRIMARY_JOINTS, primary_joints_for
from app.ml.analyzers.registry import ANALYZER_REGISTRY
from app.ml.pose_estimator import Keypoint
from app.ml.similarity_scorer import WINDOW, SimilarityScorer

# Analyzer thật sự tính calculate_angle_3d(shoulder, elbow, wrist) — DEFAULT_JOINTS
# đúng cho những cái này (đã xác nhận bằng cách đọc trực tiếp code từng file,
# xem CHANGELOG 13/09/2026). Bất kỳ analyzer nào KHÔNG có trong tập này thì
# BẮT BUỘC phải khai trong PRIMARY_JOINTS — rơi vào mặc định là chấm sai góc.
_CORRECT_WITH_DEFAULT_JOINTS = frozenset({
    "RowAnalyzer",
    "CurlAnalyzer",
    "BenchPressAnalyzer",
    "OverheadPressAnalyzer",
    "PulldownAnalyzer",
    "TricepExtensionAnalyzer",
    "FacePullAnalyzer",
})


def test_moi_analyzer_deu_co_khop_dung_hoac_nam_trong_danh_sach_mac_dinh_dung() -> None:
    """Khoá lại đúng lỗ hổng đã tìm thấy 13/09/2026: `reference_joints.py`
    khi viết chỉ liệt kê 6/16 analyzer lúc đó, khiến LateralRaise/ChestFly/
    Pullover (tính góc ở VAI, không phải khuỷu tay) âm thầm rơi vào
    DEFAULT_JOINTS sai suốt nhiều ngày, và các analyzer thêm sau đó
    (HipAbduction/HipAdduction/Kickback/CossackSquat/LegCurl/LegPress/
    Crunch/CatCow/Plank) cũng chưa từng được thêm vào. Test này buộc MỌI
    analyzer trong ANALYZER_REGISTRY phải được xét tới một cách tường minh —
    hoặc có trong PRIMARY_JOINTS, hoặc nằm trong danh sách đã xác nhận dùng
    đúng DEFAULT_JOINTS — không được âm thầm rơi vào mặc định mà chưa ai
    kiểm chứng."""
    known_analyzer_names = {cls.__name__ for cls in ANALYZER_REGISTRY.values()}
    unaccounted = known_analyzer_names - set(PRIMARY_JOINTS) - _CORRECT_WITH_DEFAULT_JOINTS
    assert not unaccounted, (
        f"Analyzer chưa xác nhận khớp nào đại diện đúng: {sorted(unaccounted)} — "
        "thêm vào PRIMARY_JOINTS (đọc code analyzer để biết khớp đúng) hoặc "
        "vào _CORRECT_WITH_DEFAULT_JOINTS nếu đã xác nhận nó tính "
        "calculate_angle_3d(shoulder, elbow, wrist)."
    )


@pytest.mark.parametrize(
    ("analyzer_name", "expected"),
    [
        ("HipAbductionAnalyzer", ("left_shoulder", "left_hip", "left_knee")),
        ("HipAdductionAnalyzer", ("left_shoulder", "left_hip", "left_knee")),
        ("KickbackAnalyzer", ("left_shoulder", "left_hip", "left_knee")),
        ("CrunchAnalyzer", ("left_shoulder", "left_hip", "left_knee")),
        ("CossackSquatAnalyzer", ("left_hip", "left_knee", "left_ankle")),
        ("LegCurlAnalyzer", ("left_hip", "left_knee", "left_ankle")),
        ("LegPressAnalyzer", ("left_hip", "left_knee", "left_ankle")),
        ("LateralRaiseAnalyzer", ("left_hip", "left_shoulder", "left_elbow")),
        ("ChestFlyAnalyzer", ("left_hip", "left_shoulder", "left_elbow")),
        ("PulloverAnalyzer", ("left_hip", "left_shoulder", "left_elbow")),
        # Vẫn đúng dùng DEFAULT_JOINTS — khoá lại để không ai "sửa nhầm" thêm
        # entry thừa cho những cái này.
        ("RowAnalyzer", DEFAULT_JOINTS),
        ("CurlAnalyzer", DEFAULT_JOINTS),
    ],
)
def test_primary_joints_dung_tung_analyzer(analyzer_name: str, expected: tuple[str, str, str]) -> None:
    assert primary_joints_for(analyzer_name) == expected


@pytest.fixture(autouse=True)
def _clear_cache():
    reference_library.get_reference.cache_clear()
    yield
    reference_library.get_reference.cache_clear()


def _kp(x, y, z=0.0) -> Keypoint:
    return Keypoint(x=x, y=y, z=z, visibility=1.0)


def _named_keypoints_for_angle(degrees: float) -> dict[str, Keypoint]:
    """Dựng 3 khớp mặc định (left_shoulder/left_elbow/left_wrist, xem
    `reference_joints.DEFAULT_JOINTS`) sao cho góc tại khuỷu tay đúng bằng
    `degrees` trong mặt phẳng x/y — tái dùng cách dựng của `tests/pose_builders.py`."""
    from tests.pose_builders import place_at_angle

    shoulder = _kp(0.5, 0.3)
    elbow = _kp(0.5, 0.5)
    wrist = place_at_angle(shoulder, elbow, degrees)
    return {"left_shoulder": shoulder, "left_elbow": elbow, "left_wrist": wrist}


def _install_fake_reference(monkeypatch, angle_series: tuple[float, ...], projection: str = "x/y") -> None:
    ref = reference_library.ReferenceMotion(
        exercise="fake", analyzer="FakeAnalyzer", projection=projection, angle_series=angle_series
    )
    monkeypatch.setattr(reference_library, "get_reference", lambda exercise: ref)
    import app.ml.similarity_scorer as similarity_scorer_module

    monkeypatch.setattr(similarity_scorer_module, "get_reference", lambda exercise: ref)


def test_no_reference_always_returns_none(monkeypatch):
    import app.ml.similarity_scorer as similarity_scorer_module

    monkeypatch.setattr(similarity_scorer_module, "get_reference", lambda exercise: None)
    scorer = SimilarityScorer("bai khong co chuan")

    assert scorer.has_reference is False
    for degrees in [90, 120, 150, 90, 120, 150] * 10:
        assert scorer.update(_named_keypoints_for_angle(degrees)) is None


def test_returns_none_until_window_is_full(monkeypatch):
    _install_fake_reference(monkeypatch, tuple(float(90 + i) for i in range(60)))
    scorer = SimilarityScorer("fake", window=WINDOW)

    results = [scorer.update(_named_keypoints_for_angle(90 + i)) for i in range(WINDOW - 1)]

    assert all(r is None for r in results)


def test_perfect_match_scores_near_100(monkeypatch):
    # Chuẩn: một chu kỳ rep đi lên rồi xuống, 90° -> 170° -> 90°, 60 frame.
    ref_series = tuple(
        90.0 + 80.0 * abs(((i / 30.0) % 2.0) - 1.0) for i in range(60)
    )
    _install_fake_reference(monkeypatch, ref_series)
    scorer = SimilarityScorer("fake", window=WINDOW)

    # Tập ĐÚNG Y HỆT chuẩn — cửa sổ live là chính đoạn cuối của chuẩn.
    scores = [scorer.update(_named_keypoints_for_angle(a)) for a in ref_series]

    final_score = scores[-1]
    assert final_score is not None
    assert final_score > 95.0


def test_standing_still_in_range_scores_zero(monkeypatch):
    """Bẫy phát hiện ở `dtw_prototype.py`: đứng yên trong phạm vi chuyển
    động của bài không được phép ra điểm cao giả tạo — xem CHANGELOG
    11/09/2026 (3)."""
    ref_series = tuple(90.0 + 80.0 * abs(((i / 30.0) % 2.0) - 1.0) for i in range(60))
    _install_fake_reference(monkeypatch, ref_series)
    scorer = SimilarityScorer("fake", window=WINDOW)

    scores = [scorer.update(_named_keypoints_for_angle(130.0)) for _ in range(WINDOW)]

    assert scores[-1] == 0.0


def test_dung_dua_nhe_trong_pham_vi_khong_duoc_diem_cao_gia_tao(monkeypatch):
    """Lỗ hổng phát hiện lúc audit 17/09/2026: chặn "đứng yên tuyệt đối" ở
    test ngay trên (biên độ live = 0) không bắt được người tập LẮC LƯ NHẸ
    (biên độ ≥ `MIN_LIVE_RANGE_DEGREES`, qua được chặn đó) quanh một góc nằm
    trong vùng chuyển động của bài — DTW không giới hạn số bước "dính" cùng
    một điểm chuẩn thì vẫn tìm được vài điểm chuẩn gần giá trị đang lắc lư
    rồi lặp lại gần như miễn phí, ra điểm cao giả tạo dù không hề đi hết
    biên độ như chuẩn yêu cầu.

    Xác nhận bằng cách so sánh CHÍNH chuỗi live đó qua hai giá trị
    `MAX_CONSECUTIVE_STALL`: chặn lỏng (mô phỏng lại đúng hành vi CŨ trước
    khi sửa) phải ra điểm cao giả tạo, chặn thật (giá trị đang dùng trong
    code) phải ra điểm thấp hơn hẳn — không chỉ kiểm một ngưỡng tuyệt đối
    (dễ vỡ nếu đổi SCALE_DEGREES sau này) mà kiểm ĐÚNG SỰ KHÁC BIỆT mà bản
    sửa này tạo ra."""
    import app.ml.similarity_scorer as similarity_scorer_module

    ref_series = tuple(90.0 + 80.0 * abs(((i / 30.0) % 2.0) - 1.0) for i in range(60))
    _install_fake_reference(monkeypatch, ref_series)

    # Phần lớn cửa sổ (26/30 frame) đứng gần như im tại 130° — chỉ 4 frame
    # lệch ra 110°/150° để biên độ tổng đạt 40° (> MIN_LIVE_RANGE_DEGREES=8,
    # qua được chặn đứng-yên-tuyệt-đối). Mốc 130° chỉ xuất hiện ở đúng 2 chỉ
    # số của chuẩn (i=15, i=45, xem công thức reference ở trên) — DTW không
    # giới hạn "dính" sẽ ghim gần hết 26 frame đó vào 1-2 chỉ số rẻ nhất rồi
    # gần như bỏ qua toàn bộ phần chuẩn còn lại, đúng kiểu lỗi đã ghi nhận.
    live_series = [130.0] * 13 + [110.0, 150.0] + [130.0] * 13 + [110.0, 150.0]

    def score_with_stall_cap(cap: int) -> float:
        monkeypatch.setattr(similarity_scorer_module, "MAX_CONSECUTIVE_STALL", cap)
        scorer = SimilarityScorer("fake", window=WINDOW)
        scores = [scorer.update(_named_keypoints_for_angle(a)) for a in live_series]
        assert scores[-1] is not None
        return scores[-1]

    # Chặn lỏng gần như không giới hạn — mô phỏng lại hành vi CŨ (bug thật).
    score_khong_chan = score_with_stall_cap(cap=WINDOW)
    # Chặn thật, khớp giá trị mặc định của code hiện tại.
    score_co_chan = score_with_stall_cap(cap=3)

    assert score_khong_chan > 90.0, (
        f"score_khong_chan={score_khong_chan} — nếu số này KHÔNG cao thì "
        "chuỗi live/reference dựng trong test không thật sự tái hiện được "
        "bug gốc, cần dựng lại kịch bản."
    )
    assert score_co_chan < score_khong_chan - 10.0, (
        f"score_co_chan={score_co_chan} so với score_khong_chan={score_khong_chan} "
        "— ràng buộc step-pattern không tạo ra khác biệt đáng kể, chưa sửa "
        "được lỗ hổng đung đưa nhẹ."
    )


def test_uses_projection_stored_in_reference_not_a_fixed_choice(monkeypatch):
    """Bẫy suýt lọt lúc viết code: từng có lỗi luôn dùng 2D bất kể
    `projection` là gì (điều kiện `if self._reference.analyzer` luôn đúng
    vì đó là chuỗi khác rỗng) — khoá lại bằng test để không tái phạm.

    Dựng chuyển động chỉ lộ ra ở trục z (a, b cố định trong x/y; c trượt
    theo z) — chiếu 2D (bỏ qua z) sẽ luôn thấy y hệt 180° không đổi ở MỌI
    frame, tức "không thấy chuyển động", còn chiếu 3D đúng mới thấy góc
    thay đổi thật theo chuẩn."""
    from app.ml.angle_utils import calculate_angle_3d

    a, b = _kp(0.3, 0.5, 0.0), _kp(0.5, 0.5, 0.0)
    z_values = [0.3 * i / (WINDOW - 1) for i in range(WINDOW)]
    frames_3d = [(a, b, _kp(0.7, 0.5, z)) for z in z_values]
    ref_series = tuple(calculate_angle_3d(fa, fb, fc) for fa, fb, fc in frames_3d)

    _install_fake_reference(monkeypatch, ref_series, projection="x/y/z")
    scorer = SimilarityScorer("fake", window=WINDOW)

    scores = [
        scorer.update({"left_shoulder": fa, "left_elbow": fb, "left_wrist": fc})
        for fa, fb, fc in frames_3d
    ]

    # Nếu lỡ dùng nhầm 2D: mọi frame đọc ra đúng 180° (bỏ qua z), biên độ
    # cửa sổ live = 0 -> chặn "đứng yên" kích hoạt -> điểm 0, KHÔNG phải
    # gần 100 như khi dùng đúng 3D và live khớp y hệt chuẩn.
    assert scores[-1] is not None
    assert scores[-1] > 95.0
