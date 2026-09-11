"""Test `app/ml/reference_library.py` — đọc + cache chuẩn tham chiếu."""

import json

import pytest

from app.ml import reference_library
from app.ml.angle_utils import calculate_angle
from app.ml.pose_estimator import Keypoint


@pytest.fixture(autouse=True)
def _isolate_reference_dir(tmp_path, monkeypatch):
    """Mỗi test dùng một thư mục chuẩn riêng, và cache `lru_cache` phải xoá
    trước/sau mỗi test — nếu không, test chạy sau sẽ đọc nhầm kết quả cache
    từ test chạy trước (cùng tên bài, khác nội dung file)."""
    monkeypatch.setattr(reference_library, "REFERENCE_DIR", tmp_path)
    reference_library.get_reference.cache_clear()
    yield
    reference_library.get_reference.cache_clear()


def _write_reference(tmp_path, name: str, *, projection: str, frames: list[dict]) -> None:
    path = tmp_path / f"{name}.json"
    path.write_text(
        json.dumps({
            "exercise": name,
            "analyzer": "FakeAnalyzer",
            "projection": projection,
            "missing_rate": 0.0,
            "frames": frames,
        }),
        encoding="utf-8",
    )


def _frame(shoulder, elbow, wrist) -> dict:
    def pt(x, y, z):
        return {"x": x, "y": y, "z": z, "visibility": 1.0}

    return {
        "left_shoulder": pt(*shoulder),
        "left_elbow": pt(*elbow),
        "left_wrist": pt(*wrist),
    }


def test_missing_file_returns_none(tmp_path):
    assert reference_library.get_reference("khong ton tai") is None


def test_corrupt_json_returns_none(tmp_path):
    (tmp_path / "loi.json").write_text("{khong phai json hop le", encoding="utf-8")
    assert reference_library.get_reference("loi") is None


def test_too_few_frames_returns_none(tmp_path):
    _write_reference(tmp_path, "qua_ngan", projection="x/y", frames=[_frame((0, 0, 0), (0.2, 0, 0), (0.4, 0, 0))])
    assert reference_library.get_reference("qua_ngan") is None


def test_computes_angle_series_matching_analyzer_formula(tmp_path):
    frames = [
        _frame((0.3, 0.5, 0.0), (0.5, 0.5, 0.0), (0.7, 0.5, 0.0)),  # thẳng hàng, 180°
        _frame((0.3, 0.5, 0.0), (0.5, 0.5, 0.0), (0.5, 0.3, 0.0)),  # vuông góc, 90°
    ]
    _write_reference(tmp_path, "hai_frame", projection="x/y", frames=frames)

    ref = reference_library.get_reference("hai_frame")

    assert ref is not None
    assert ref.projection == "x/y"
    expected = [
        calculate_angle(Keypoint(0.3, 0.5, 0.0, 1.0), Keypoint(0.5, 0.5, 0.0, 1.0), Keypoint(0.7, 0.5, 0.0, 1.0)),
        calculate_angle(Keypoint(0.3, 0.5, 0.0, 1.0), Keypoint(0.5, 0.5, 0.0, 1.0), Keypoint(0.5, 0.3, 0.0, 1.0)),
    ]
    assert list(ref.angle_series) == pytest.approx(expected)


def test_result_is_cached_between_calls(tmp_path):
    frames = [_frame((0.3, 0.5, 0), (0.5, 0.5, 0), (0.7, 0.5, 0)), _frame((0.3, 0.5, 0), (0.5, 0.5, 0), (0.5, 0.3, 0))]
    _write_reference(tmp_path, "cache_test", projection="x/y", frames=frames)

    first = reference_library.get_reference("cache_test")
    (tmp_path / "cache_test.json").unlink()  # xoá file — nếu KHÔNG cache thì lần đọc sau sẽ ra None
    second = reference_library.get_reference("cache_test")

    assert first is second


def test_lookup_is_case_and_space_insensitive(tmp_path):
    frames = [_frame((0.3, 0.5, 0), (0.5, 0.5, 0), (0.7, 0.5, 0)), _frame((0.3, 0.5, 0), (0.5, 0.5, 0), (0.5, 0.3, 0))]
    _write_reference(tmp_path, "band_squat", projection="x/y", frames=frames)

    assert reference_library.get_reference("Band Squat") is not None
