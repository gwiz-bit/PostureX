"""Test `app/ml/similarity_scorer.py` — chấm điểm "độ giống bài mẫu"."""

import pytest

from app.ml import reference_library
from app.ml.pose_estimator import Keypoint
from app.ml.similarity_scorer import WINDOW, SimilarityScorer


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
