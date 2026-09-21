"""Test chế độ `input: "keypoints"` — client tự nhận diện tư thế, server chỉ phân tích.

Hai tầng: hàm phân tích thuần (`parse_client_keypoints`) và chuỗi WebSocket đầy
đủ. Điều quan trọng nhất cần khoá lại là (1) kết quả PHẢI giống hệt đường ảnh
JPEG khi cùng một tư thế, (2) server không được đụng tới MediaPipe ở chế độ
này, (3) mọi frame — kể cả frame hỏng — đều nhận ĐÚNG MỘT phản hồi, vì client
ghép cặp gửi/nhận theo thứ tự (xem `_pendingRequestTimestamps` phía Flutter).
"""

import json
import math

import pytest
from fastapi.testclient import TestClient

from app.api.v1.routes import realtime
from app.core.security import create_access_token
from app.main import app
from app.ml.client_keypoints import LANDMARK_COUNT, parse_client_keypoints
from tests.pose_builders import squat_pose
from tests.test_analyzers import rep_sequence

WS_URL = "/api/v1/ws/analyze"


def _payload(pose) -> str:
    return json.dumps({"keypoints": [[k.x, k.y, k.z, k.visibility] for k in pose]})


# ─────────────────────────────────────────────────────────────────────
# Hàm phân tích thuần
# ─────────────────────────────────────────────────────────────────────


def test_parse_khop_le_giu_nguyen_gia_tri() -> None:
    pose = squat_pose(120.0, 175.0)
    parsed = parse_client_keypoints(_payload(pose))

    assert parsed is not None
    assert len(parsed) == LANDMARK_COUNT
    for got, want in zip(parsed, pose, strict=True):
        assert (got.x, got.y, got.z, got.visibility) == pytest.approx(
            (want.x, want.y, want.z, want.visibility)
        )


def test_parse_nhan_ca_bytes_lan_text() -> None:
    text = _payload(squat_pose(120.0, 175.0))
    assert parse_client_keypoints(text.encode("utf-8")) is not None


def test_parse_null_nghia_la_khong_thay_nguoi() -> None:
    assert parse_client_keypoints('{"keypoints": null}') is None


@pytest.mark.parametrize(
    "bad",
    [
        "khong phai json",
        "[]",
        "{}",
        '{"keypoints": "abc"}',
        '{"keypoints": []}',
        json.dumps({"keypoints": [[0.5, 0.5, 0.0, 1.0]] * (LANDMARK_COUNT - 1)}),
        json.dumps({"keypoints": [[0.5, 0.5, 0.0]] * LANDMARK_COUNT}),
        json.dumps({"keypoints": [[0.5, 0.5, 0.0, "cao"]] * LANDMARK_COUNT}),
        json.dumps({"keypoints": [[0.5, 0.5, 0.0, True]] * LANDMARK_COUNT}),
    ],
)
def test_parse_du_lieu_sai_dinh_dang_bi_tu_choi(bad: str) -> None:
    with pytest.raises(ValueError):  # noqa: PT011
        parse_client_keypoints(bad)


def test_parse_khong_phai_utf8_bi_tu_choi() -> None:
    with pytest.raises(ValueError):  # noqa: PT011
        parse_client_keypoints(b"\xff\xfe\x00")


def test_parse_tu_choi_toa_do_con_o_don_vi_pixel() -> None:
    """Bẫy đáng sợ nhất: client quên chuẩn hoá thì mọi góc tính ra đều vô nghĩa
    mà không có lỗi nào báo. Toạ độ pixel (vd 640) phải bị chặn ngay cửa."""
    pixel_pose = [[640.0, 480.0, 0.0, 1.0]] * LANDMARK_COUNT
    with pytest.raises(ValueError, match="chuẩn hoá"):
        parse_client_keypoints(json.dumps({"keypoints": pixel_pose}))


def test_parse_tu_choi_nan_va_inf() -> None:
    # `json.dumps` mặc định vẫn sinh ra NaN/Infinity (không chuẩn JSON, nhưng
    # `json.loads` của Python lại đọc được) — nên phải kiểm tường minh.
    for bad_value in (math.nan, math.inf):
        row = [[0.5, 0.5, 0.0, 1.0]] * LANDMARK_COUNT
        row[3] = [bad_value, 0.5, 0.0, 1.0]
        with pytest.raises(ValueError, match="hữu hạn"):
            parse_client_keypoints(json.dumps({"keypoints": row}))


def test_parse_kep_visibility_vao_0_1() -> None:
    row = [[0.5, 0.5, 0.0, 1.7]] * LANDMARK_COUNT
    row[0] = [0.5, 0.5, 0.0, -0.3]
    parsed = parse_client_keypoints(json.dumps({"keypoints": row}))
    assert parsed is not None
    assert parsed[0].visibility == 0.0
    assert parsed[1].visibility == 1.0


def test_parse_cho_phep_khop_hoi_vuot_khung_hinh() -> None:
    """Khớp ngoài khung hình (x hơi âm, y hơi >1) là hợp lệ, không được từ chối."""
    row = [[0.5, 0.5, 0.0, 1.0]] * LANDMARK_COUNT
    row[0] = [-0.05, 1.08, 0.0, 0.3]
    assert parse_client_keypoints(json.dumps({"keypoints": row})) is not None


# ─────────────────────────────────────────────────────────────────────
# Chuỗi WebSocket đầy đủ
# ─────────────────────────────────────────────────────────────────────


@pytest.fixture
def ws_client(monkeypatch):
    monkeypatch.setattr("app.main.start_scheduler", lambda: None)
    monkeypatch.setattr("app.main.shutdown_scheduler", lambda: None)

    async def no_thresholds(_exercise: str) -> dict[str, float]:
        return {}

    monkeypatch.setattr(realtime, "_load_exercise_thresholds", no_thresholds)
    return TestClient(app)


def _forbid_server_pose_estimation(monkeypatch) -> None:
    """Ở chế độ keypoint, server KHÔNG được chạy MediaPipe — đó chính là mục
    đích của cả tính năng. Nếu lỡ gọi thì test đỏ ngay."""

    async def must_not_be_called(_frame_bytes):
        raise AssertionError("Chế độ keypoints không được gọi pose estimation của server")

    monkeypatch.setattr(realtime._pose_estimator_pool, "estimate", must_not_be_called)


def _connect(ws_client: TestClient, exercise: str = "squat", **init_extra):
    ws = ws_client.websocket_connect(f"{WS_URL}?token={create_access_token('1')}")
    return ws, {"exercise": exercise, **init_extra}


def test_ready_echo_dung_che_do_da_chon(ws_client: TestClient) -> None:
    ctx, init = _connect(ws_client, input="keypoints")
    with ctx as ws:
        ws.send_text(json.dumps(init))
        assert ws.receive_json()["input"] == "keypoints"


def test_mac_dinh_van_la_anh_jpeg_de_client_cu_khong_vo(ws_client: TestClient) -> None:
    ctx, init = _connect(ws_client)
    with ctx as ws:
        ws.send_text(json.dumps(init))
        assert ws.receive_json()["input"] == "image"


def test_che_do_la_bi_ha_ve_anh_jpeg(ws_client: TestClient) -> None:
    ctx, init = _connect(ws_client, input="hologram")
    with ctx as ws:
        ws.send_text(json.dumps(init))
        assert ws.receive_json()["input"] == "image"


def test_dem_dung_rep_qua_keypoint_khong_can_pose_estimation(ws_client: TestClient, monkeypatch) -> None:
    _forbid_server_pose_estimation(monkeypatch)
    angles = rep_sequence(170, 85)

    ctx, init = _connect(ws_client, input="keypoints")
    with ctx as ws:
        ws.send_text(json.dumps(init))
        ws.receive_json()

        last = None
        for angle in angles:
            ws.send_text(_payload(squat_pose(angle, 175.0)))
            last = ws.receive_json()

    # Y hệt `test_phien_tra_ve_ket_qua_tung_frame` của đường ảnh JPEG.
    assert last["rep_count"] == 1
    assert last["errors"] == []
    assert last["correct"] is True
    assert last["key_angles"]["left_knee"] is not None
    assert last["keypoints"] is not None


def test_null_bao_khong_thay_nguoi_va_giu_phien(ws_client: TestClient, monkeypatch) -> None:
    _forbid_server_pose_estimation(monkeypatch)

    ctx, init = _connect(ws_client, input="keypoints")
    with ctx as ws:
        ws.send_text(json.dumps(init))
        ws.receive_json()

        ws.send_text('{"keypoints": null}')
        result = ws.receive_json()
        assert result["errors"] == ["Không phát hiện được người trong frame."]
        assert result["keypoints"] is None

        # Người quay lại khung hình — phiên vẫn chạy trên CÙNG kết nối.
        ws.send_text(_payload(squat_pose(170.0, 175.0)))
        assert ws.receive_json()["keypoints"] is not None


def test_frame_keypoint_hong_nhan_dung_mot_phan_hoi_va_khong_dut_phien(
    ws_client: TestClient, monkeypatch
) -> None:
    """Client ghép cặp gửi/nhận theo thứ tự nên frame hỏng vẫn PHẢI có đúng
    một phản hồi (lỗi) — thiếu một cái là mọi số đo latency sau đó lệch một nấc."""
    _forbid_server_pose_estimation(monkeypatch)

    ctx, init = _connect(ws_client, input="keypoints")
    with ctx as ws:
        ws.send_text(json.dumps(init))
        ws.receive_json()

        ws.send_text("!!! khong phai json !!!")
        assert "error" in ws.receive_json()

        ws.send_text(json.dumps({"keypoints": [[640.0, 480.0, 0.0, 1.0]] * LANDMARK_COUNT}))
        assert "chuẩn hoá" in ws.receive_json()["error"]

        ws.send_text(_payload(squat_pose(170.0, 175.0)))
        assert "rep_count" in ws.receive_json()


def test_ket_qua_keypoint_giong_het_ket_qua_anh_jpeg(ws_client: TestClient, monkeypatch) -> None:
    """Cùng một dãy tư thế đi hai đường phải cho cùng kết quả — nếu lệch nghĩa
    là nhánh mới đã làm đổi hành vi phân tích, thứ không được phép xảy ra."""
    angles = rep_sequence(170, 85)

    def run(mode: str) -> list[dict]:
        remaining = list(angles)

        async def fake_estimate(_frame_bytes):
            return squat_pose(remaining.pop(0), 175.0)

        monkeypatch.setattr(realtime._pose_estimator_pool, "estimate", fake_estimate)
        results = []
        ctx, init = _connect(ws_client, input=mode)
        with ctx as ws:
            ws.send_text(json.dumps(init))
            ws.receive_json()
            for angle in angles:
                if mode == "keypoints":
                    ws.send_text(_payload(squat_pose(angle, 175.0)))
                else:
                    ws.send_bytes(b"frame")
                results.append(ws.receive_json())
        return results

    via_image = run("image")
    via_keypoints = run("keypoints")

    for a, b in zip(via_image, via_keypoints, strict=True):
        assert a["rep_count"] == b["rep_count"]
        assert a["phase"] == b["phase"]
        assert a["errors"] == b["errors"]
        assert a["correct"] == b["correct"]
        assert a["key_angles"] == pytest.approx(b["key_angles"], abs=1e-3)
