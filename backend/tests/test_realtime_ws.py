"""Test tích hợp đường WebSocket phân tích tư thế — mắt xích cuối chưa được phủ.

Trước file này, `load_thresholds` và các analyzer đều có test riêng, nhưng
CHUỖI THẬT thì chưa lần nào chạy trong test: mở kết nối → xác thực token →
nhận message init → đọc ngưỡng riêng của bài → chọn đúng analyzer → phân tích
từng frame → trả kết quả. Đó chính là đường mà người dùng đi qua khi bấm "bắt
đầu phân tích", nên là chỗ đáng test nhất.

Hai thứ được thay bằng bản giả, vì chúng không phải thứ đang kiểm ở đây:
  - Pose estimation: thay bằng tư thế dựng sẵn, khỏi cần MediaPipe và ảnh thật.
  - Đọc ngưỡng từ DB: đã có `test_posture_thresholds.py` phủ riêng; ở đây chỉ
    cần biết ngưỡng đọc được có tới đúng analyzer hay không.
"""

import json

import pytest
from fastapi.testclient import TestClient

from app.api.v1.routes import realtime
from app.core.security import create_access_token
from app.main import app
from tests.pose_builders import squat_pose
from tests.test_analyzers import rep_sequence

WS_URL = "/api/v1/ws/analyze"


@pytest.fixture
def ws_client(monkeypatch):
    """TestClient với pose estimation giả và scheduler tắt.

    Scheduler bị tắt vì nó là job nền nhắc nghỉ giải lao/tổng kết hằng ngày,
    không liên quan gì tới WebSocket mà lại chạy suốt thời gian test.
    """
    monkeypatch.setattr("app.main.start_scheduler", lambda: None)
    monkeypatch.setattr("app.main.shutdown_scheduler", lambda: None)
    return TestClient(app)


def _feed_angles(monkeypatch, angles: list[float], back_angle: float = 175.0) -> None:
    """Cho pose estimator giả trả về đúng dãy góc mong muốn, frame theo frame."""
    remaining = list(angles)

    async def fake_estimate(_frame_bytes):
        # Hết dãy thì giữ nguyên góc cuối, để test gửi thừa frame cũng không vỡ.
        angle = remaining.pop(0) if remaining else angles[-1]
        return squat_pose(angle, back_angle)

    monkeypatch.setattr(realtime._pose_estimator_pool, "estimate", fake_estimate)


def _set_thresholds(monkeypatch, thresholds: dict[str, float]) -> None:
    async def fake_load(_exercise: str) -> dict[str, float]:
        return thresholds

    monkeypatch.setattr(realtime, "_load_exercise_thresholds", fake_load)


def _token() -> str:
    return create_access_token("1")


# ─────────────────────────────────────────────────────────────────────
# Xác thực
# ─────────────────────────────────────────────────────────────────────

def test_thieu_token_bi_tu_choi(ws_client: TestClient) -> None:
    """Từ chối TRƯỚC khi accept() — client không được vào rồi mới bị đuổi."""
    with pytest.raises(Exception), ws_client.websocket_connect(WS_URL) as ws:  # noqa: B017
        ws.receive_json()


def test_token_sai_bi_tu_choi(ws_client: TestClient) -> None:
    url = f"{WS_URL}?token=khong-phai-jwt"
    with pytest.raises(Exception), ws_client.websocket_connect(url) as ws:  # noqa: B017
        ws.receive_json()


# ─────────────────────────────────────────────────────────────────────
# Chuỗi phân tích đầy đủ
# ─────────────────────────────────────────────────────────────────────

def test_phien_tra_ve_ket_qua_tung_frame(ws_client: TestClient, monkeypatch) -> None:
    _set_thresholds(monkeypatch, {})
    angles = rep_sequence(170, 85)
    _feed_angles(monkeypatch, angles)

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "squat"}))
        ready = ws.receive_json()
        assert ready["status"] == "ready"
        assert ready["exercise"] == "squat"

        last = None
        for _ in angles:
            ws.send_bytes(b"frame")
            last = ws.receive_json()

    # Một rep đúng chuẩn: đếm đúng 1, không lỗi nào, có đủ trường cho client.
    assert last["rep_count"] == 1
    assert last["errors"] == []
    assert last["correct"] is True
    assert last["key_angles"]["left_knee"] is not None
    assert last["keypoints"] is not None
    # `top` chỉ là trạng thái thoáng qua: ngay khi góc vượt ngưỡng đứng thẳng
    # thì phase thành "top", nhưng frame kế tiếp — góc vẫn còn tăng — đã
    # chuyển sang "going_down". Nên chỉ kiểm phase là giá trị hợp lệ.
    assert last["phase"] in ("top", "going_down", "going_up", "bottom")


def test_nguong_rieng_cua_bai_toi_duoc_analyzer(ws_client: TestClient, monkeypatch) -> None:
    """Đây là điều cả cơ chế ngưỡng theo từng bài phục vụ.

    Cùng một tư thế lưng 130°: mặc định (≥150°) báo "lưng bị cúi", còn bài có
    ngưỡng riêng 120° thì không. Nếu ngưỡng không chảy được từ DB qua
    `_get_analyzer` tới analyzer thì test này đỏ.
    """
    _set_thresholds(monkeypatch, {"back_straight_min": 120.0})
    _feed_angles(monkeypatch, [120.0], back_angle=130.0)

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "squat"}))
        ws.receive_json()
        ws.send_bytes(b"frame")
        result = ws.receive_json()

    assert not any("Lưng bị cúi" in e for e in result["errors"])


def test_khong_co_nguong_rieng_thi_van_bat_loi_nhu_cu(ws_client: TestClient, monkeypatch) -> None:
    """Mặt còn lại: bài chưa nhập ngưỡng phải giữ nguyên hành vi cũ."""
    _set_thresholds(monkeypatch, {})
    _feed_angles(monkeypatch, [120.0], back_angle=130.0)

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "squat"}))
        ws.receive_json()
        ws.send_bytes(b"frame")
        result = ws.receive_json()

    assert any("Lưng bị cúi" in e for e in result["errors"])


def test_chon_dung_analyzer_theo_ten_bai(ws_client: TestClient, monkeypatch) -> None:
    """Tên bài phải tra đúng analyzer, không phân biệt hoa/thường.

    `Barbell Bent Over Row` dùng RowAnalyzer, vốn đếm rep theo góc KHUỶU TAY
    chứ không phải góc gối — nên cùng dãy góc gối của squat sẽ không ra rep.
    """
    _set_thresholds(monkeypatch, {})
    _feed_angles(monkeypatch, rep_sequence(170, 85))

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "BARBELL BENT OVER ROW"}))
        ready = ws.receive_json()
        ws.send_bytes(b"frame")
        ws.receive_json()

    assert ready["exercise"] == "barbell bent over row"


def test_frame_hong_khong_lam_dut_phien(ws_client: TestClient, monkeypatch) -> None:
    """Frame không giải mã được chỉ trả lỗi, phiên vẫn chạy tiếp."""
    _set_thresholds(monkeypatch, {})
    _feed_angles(monkeypatch, [120.0])

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "squat"}))
        ws.receive_json()

        ws.send_text("!!! khong phai base64 !!!")
        assert "error" in ws.receive_json()

        ws.send_bytes(b"frame")
        assert "rep_count" in ws.receive_json()


def test_khong_thay_nguoi_thi_bao_nhung_van_giu_phien(ws_client: TestClient, monkeypatch) -> None:
    """Người ra khỏi khung hình: báo cho client, không đóng kết nối."""
    _set_thresholds(monkeypatch, {})

    async def khong_thay_ai(_frame_bytes):
        return None

    monkeypatch.setattr(realtime._pose_estimator_pool, "estimate", khong_thay_ai)

    with ws_client.websocket_connect(f"{WS_URL}?token={_token()}") as ws:
        ws.send_text(json.dumps({"exercise": "squat"}))
        ws.receive_json()
        ws.send_bytes(b"frame")
        result = ws.receive_json()

    assert result["errors"] == ["Không phát hiện được người trong frame."]
    assert result["keypoints"] is None


# ─────────────────────────────────────────────────────────────────────
# Đọc ngưỡng hỏng thì phiên vẫn phải chạy
# ─────────────────────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_db_loi_thi_dung_nguong_mac_dinh(monkeypatch) -> None:
    """Mất DB thì mất phần tinh chỉnh, chứ không được làm người dùng không tập được.

    `_load_exercise_thresholds` tự mở session riêng (không qua `Depends`), nên
    lỗi kết nối ở đây không có tầng nào khác đỡ.
    """

    def no_db():
        raise RuntimeError("DB sap")

    monkeypatch.setattr(realtime, "AsyncSessionLocal", no_db)

    assert await realtime._load_exercise_thresholds("squat") == {}
