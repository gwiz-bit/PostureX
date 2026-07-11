"""WebSocket endpoint phân tích tư thế thời gian thực."""

import base64
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.pose_estimator import PoseEstimator
from app.ml.session_state import SessionState
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

logger = logging.getLogger(__name__)

router = APIRouter(tags=["realtime"])

# Khởi tạo PoseEstimator một lần cho toàn ứng dụng
_pose_estimator = PoseEstimator(model_complexity=1)

# Registry ánh xạ tên bài tập -> analyzer class
ANALYZER_REGISTRY: dict[str, type[ExerciseAnalyzer]] = {
    "squat": SquatAnalyzer,
}


def _get_analyzer(exercise: str, session: SessionState) -> ExerciseAnalyzer:
    """Tạo analyzer tương ứng với tên bài tập."""
    cls = ANALYZER_REGISTRY.get(exercise.lower())
    if cls is None:
        # Mặc định dùng squat nếu chưa hỗ trợ bài tập đó
        logger.warning("Bài tập '%s' chưa được hỗ trợ, dùng squat mặc định.", exercise)
        cls = SquatAnalyzer
    return cls(rep_counter=session.rep_counter)


def _decode_frame(data: bytes | str) -> bytes:
    """
    Nhận raw bytes (JPEG) hoặc base64 string, trả về JPEG bytes.

    Flutter có thể gửi cả hai định dạng tùy cách triển khai client.
    """
    if isinstance(data, bytes):
        # Thử giải mã base64; nếu không phải thì coi là JPEG thô
        try:
            return base64.b64decode(data)
        except Exception:
            return data
    # Chuỗi text — bỏ data-uri prefix nếu có
    if data.startswith("data:image"):
        data = data.split(",", 1)[1]
    return base64.b64decode(data)


@router.websocket("/ws/analyze")
async def analyze_realtime(websocket: WebSocket) -> None:
    """
    WebSocket endpoint phân tích tư thế theo từng frame.

    Giao thức:
      1. Client gửi JSON init: {"exercise": "squat"}
      2. Client gửi liên tục frame JPEG (bytes hoặc base64)
      3. Server trả JSON FrameAnalysisResult sau mỗi frame
    """
    await websocket.accept()
    session: SessionState | None = None
    analyzer: ExerciseAnalyzer | None = None

    try:
        # --- Bước 1: nhận message khởi tạo ---
        init_raw = await websocket.receive_text()
        try:
            init_data = json.loads(init_raw)
            exercise = init_data.get("exercise", "squat")
        except (json.JSONDecodeError, AttributeError):
            exercise = "squat"

        session = SessionState(exercise=exercise)
        analyzer = _get_analyzer(exercise, session)

        await websocket.send_json({
            "status": "ready",
            "exercise": session.exercise,
            "message": f"Sẵn sàng phân tích bài tập: {session.exercise}",
        })

        # --- Bước 2: vòng lặp nhận frame ---
        while True:
            raw = await websocket.receive()

            # `receive()` (khác `receive_text/bytes`) trả về cả message ngắt kết
            # nối thay vì ném WebSocketDisconnect. Không bắt ở đây thì vòng lặp
            # sẽ gọi `receive()` lần nữa trên socket đã đóng và RuntimeError —
            # nuốt mất phần tổng kết phiên bên dưới.
            if raw["type"] == "websocket.disconnect":
                raise WebSocketDisconnect(raw.get("code", 1000))

            # FastAPI WebSocket có thể nhận bytes hoặc text
            frame_data: bytes | str
            if "bytes" in raw and raw["bytes"] is not None:
                frame_data = raw["bytes"]
            elif "text" in raw and raw["text"] is not None:
                frame_data = raw["text"]
            else:
                continue

            # Decode frame thành JPEG bytes
            try:
                jpeg_bytes = _decode_frame(frame_data)
            except Exception as exc:
                logger.debug("Không giải mã được frame: %s", exc)
                await websocket.send_json({"error": "Không đọc được frame."})
                continue

            # Chạy pose estimation
            keypoints = _pose_estimator.estimate(jpeg_bytes)
            if keypoints is None:
                await websocket.send_json({
                    "rep_count": session.rep_counter.rep_count,
                    "errors": ["Không phát hiện được người trong frame."],
                    "correct": False,
                    "key_angles": KeyAngles().model_dump(),
                    "phase": session.rep_counter.phase.value,
                })
                continue

            # Phân tích kỹ thuật
            result: FrameAnalysisResult = analyzer.analyze(keypoints)
            session.record_frame(result.errors)

            await websocket.send_json(result.model_dump())

    except WebSocketDisconnect:
        acc = session.accuracy if session else 0.0
        reps = session.rep_counter.rep_count if session else 0
        logger.info(
            "Client ngắt kết nối. Bài tập: %s | Reps: %d | Độ chính xác: %.1f%%",
            session.exercise if session else "N/A",
            reps,
            acc,
        )
    except Exception as exc:
        logger.exception("Lỗi WebSocket không mong đợi: %s", exc)
        try:
            await websocket.send_json({"error": "Lỗi hệ thống phía server."})
        except Exception:
            pass
