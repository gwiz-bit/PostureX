"""WebSocket endpoint phân tích tư thế thời gian thực."""

import base64
import json
import logging

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from jose import JWTError

from app.core.database import AsyncSessionLocal
from app.core.security import decode_token
from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.common import visible_points
from app.ml.analyzers.registry import ANALYZER_REGISTRY, build_analyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.analyzers.thresholds import load_thresholds
from app.ml.client_keypoints import parse_client_keypoints
from app.ml.keypoint_smoother import KeypointSmoother
from app.ml.pose_estimator import named_keypoints
from app.ml.pose_estimator_pool import get_pose_estimator_pool
from app.ml.session_state import SessionState
from app.ml.similarity_scorer import SimilarityScorer
from app.schemas.analysis import FrameAnalysisResult, KeyAngles

logger = logging.getLogger(__name__)

router = APIRouter(tags=["realtime"])

# Hai cách client đưa tư thế vào — xem docstring `analyze_realtime`.
INPUT_IMAGE = "image"
INPUT_KEYPOINTS = "keypoints"

# Pool dùng chung cho toàn ứng dụng — cả với job phân tích video chạy nền
# (xem `get_pose_estimator_pool` trong pose_estimator_pool.py). KHÔNG gọi
# thẳng `PoseEstimator.estimate` ở đây: đó là tác vụ CPU 30-60 ms, chạy trong
# hàm async là chặn cả event loop nên mọi request khác của server phải chờ
# theo. Pool đẩy việc sang luồng riêng và giới hạn số phiên chạy song song.
_pose_estimator_pool = get_pose_estimator_pool()

# `ANALYZER_REGISTRY` nay đã chuyển sang app/ml/analyzers/registry.py —
# routes/exercises.py cũng cần biết danh sách này để trả cờ `supports_analysis`,
# mà không nên import cả module realtime (sẽ kéo theo PoseEstimator + mediapipe).


def _get_analyzer(
    exercise: str,
    session: SessionState,
    thresholds: dict[str, float] | None = None,
) -> ExerciseAnalyzer:
    """Tạo analyzer tương ứng với tên bài tập.

    KHÔNG truyền `session.rep_counter` vào analyzer — mỗi bài có ngưỡng
    góc down/up riêng (vd Row co khuỷu ở ~70°, Deadlift đứng thẳng ở
    ~165°), còn `SessionState` chỉ tạo `RepCounter()` mặc định (90/160).
    Để analyzer tự tạo RepCounter đúng ngưỡng bài đó, rồi đồng bộ ngược lại
    vào session — các chỗ khác (nhánh "không phát hiện người", log lúc ngắt
    kết nối) đọc `session.rep_counter` nên phải luôn là CÙNG một instance.
    """
    cls = ANALYZER_REGISTRY.get(exercise.lower())
    if cls is None:
        # Mặc định dùng squat nếu chưa hỗ trợ bài tập đó
        logger.warning("Bài tập '%s' chưa được hỗ trợ, dùng squat mặc định.", exercise)
        cls = SquatAnalyzer
    analyzer = build_analyzer(exercise, cls, thresholds)
    session.rep_counter = analyzer.rep_counter
    return analyzer


async def _load_exercise_thresholds(exercise: str) -> dict[str, float]:
    """Ngưỡng riêng của bài tập, đọc MỘT LẦN lúc mở phiên.

    Đọc ở đây thay vì trong vòng lặp frame: ngưỡng không đổi giữa chừng, mà
    truy vấn DB cho từng frame ở 12 fps là 12 lượt/giây cho mỗi người đang tập.

    Không mở được DB thì phiên vẫn chạy với ngưỡng mặc định — mất phần tinh
    chỉnh còn hơn để người dùng không tập được.
    """
    try:
        async with AsyncSessionLocal() as db:
            return await load_thresholds(db, exercise)
    except Exception as exc:
        logger.warning("Không đọc được ngưỡng riêng cho '%s': %s", exercise, exc)
        return {}


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
async def analyze_realtime(websocket: WebSocket, token: str | None = Query(default=None)) -> None:
    """
    WebSocket endpoint phân tích tư thế theo từng frame.

    Xác thực: client bắt buộc gửi access token qua query string
    (`/ws/analyze?token=...`), không dùng header Authorization — nhiều
    WebSocket client (kể cả trên web) không cho set header tuỳ ý lúc
    handshake. Từ chối kết nối trước khi accept() nếu thiếu/token sai.

    Giao thức:
      1. Client gửi JSON init: {"exercise": "squat"} — có thể kèm
         `"input": "keypoints"` để tự nhận diện tư thế trên máy (xem dưới)
      2. Client gửi liên tục frame JPEG (bytes hoặc base64)
      3. Server trả JSON FrameAnalysisResult sau mỗi frame

    Chế độ `input: "keypoints"` (xem `app/ml/client_keypoints.py`): bước 2 đổi
    thành frame JSON chứa 33 khớp đã nhận diện sẵn, server bỏ qua MediaPipe.
    Server LUÔN echo `input` thật sự đang dùng trong message `ready` — server
    cũ không biết chế độ này sẽ không echo, nên client dựa vào đó để quyết
    định gửi keypoint hay rơi về gửi ảnh JPEG. Cả hai chế độ đều trả đúng MỘT
    phản hồi cho mỗi frame nhận được (kể cả khi lỗi).
    """
    if token is None:
        await websocket.close(code=1008, reason="Thiếu token xác thực.")
        return
    try:
        payload = decode_token(token)
        if payload.get("sub") is None:
            raise JWTError("Thiếu subject")
    except JWTError:
        await websocket.close(code=1008, reason="Token không hợp lệ hoặc đã hết hạn.")
        return

    await websocket.accept()
    session: SessionState | None = None
    analyzer: ExerciseAnalyzer | None = None
    # Một bộ làm mượt RIÊNG cho phiên này — xem docstring KeypointSmoother
    # về lý do không dùng chung giữa các phiên (sẽ trộn người này với người
    # khác) và không đổi hẳn RunningMode của MediaPipe (xung đột với pool
    # dùng chung nhiều phiên).
    smoother = KeypointSmoother()
    # Chấm điểm "độ giống bài mẫu" — bổ sung, không thay hệ rep-counting/
    # ngưỡng hiện có (xem CHANGELOG 11/09/2026 (3)). Tạo SAU khi biết
    # `exercise` (bên dưới), vì cần tên bài để tra chuẩn tham chiếu.
    scorer: SimilarityScorer | None = None

    try:
        # --- Bước 1: nhận message khởi tạo ---
        init_raw = await websocket.receive_text()
        try:
            init_data = json.loads(init_raw)
            exercise = init_data.get("exercise", "squat")
            input_mode = init_data.get("input", INPUT_IMAGE)
        except (json.JSONDecodeError, AttributeError):
            exercise = "squat"
            input_mode = INPUT_IMAGE
        if input_mode not in (INPUT_IMAGE, INPUT_KEYPOINTS):
            logger.warning("Chế độ input '%s' không hỗ trợ, dùng ảnh JPEG.", input_mode)
            input_mode = INPUT_IMAGE

        session = SessionState(exercise=exercise)
        analyzer = _get_analyzer(exercise, session, await _load_exercise_thresholds(exercise))
        scorer = SimilarityScorer(exercise)
        logger.info("Mở phiên phân tích: bài '%s', input=%s", session.exercise, input_mode)

        await websocket.send_json({
            "status": "ready",
            "exercise": session.exercise,
            "input": input_mode,
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

            # Chuẩn bị đầu vào của frame: keypoint client đã nhận diện sẵn, hoặc
            # ảnh JPEG để server tự nhận diện. Lỗi ở đây vẫn phải trả ĐÚNG MỘT
            # phản hồi — client ghép cặp gửi/nhận theo thứ tự.
            client_keypoints = None
            jpeg_bytes = b""
            if input_mode == INPUT_KEYPOINTS:
                try:
                    client_keypoints = parse_client_keypoints(frame_data)
                except ValueError as exc:
                    logger.debug("Frame keypoint không hợp lệ: %s", exc)
                    await websocket.send_json({"error": f"Frame keypoint không hợp lệ: {exc}"})
                    continue
            else:
                try:
                    jpeg_bytes = _decode_frame(frame_data)
                except Exception as exc:
                    logger.debug("Không giải mã được frame: %s", exc)
                    await websocket.send_json({"error": "Không đọc được frame."})
                    continue

            # Xử lý MỘT frame trong try/except RIÊNG, tách khỏi khối try lớn
            # bọc cả vòng lặp (xem except Exception cuối hàm) — sửa
            # 17/09/2026: trước đây một lỗi ở đúng MỘT frame (vd bug trong
            # angle math của một analyzer với tư thế biên, hoặc NaN/Inf từ
            # `calculate_angle_3d`) rơi thẳng vào except ngoài cùng, làm
            # SẬP TOÀN BỘ phiên WebSocket — người tập thấy "mất kết nối"
            # giữa buổi tập chỉ vì một frame lỗi đáng lẽ có thể bỏ qua, y hệt
            # triệu chứng của sự cố hạ tầng libGLESv2 (06/09/2026) dù nguyên
            # nhân hoàn toàn khác (lỗi code cho MỘT frame, không phải server
            # hỏng toàn bộ) — cả hai trả về cùng một câu lỗi chung chung nên
            # không phân biệt được từ phía client. Bắt riêng ở đây: log kèm
            # nhãn "một frame" để phân biệt với log lỗi phiên ở except ngoài,
            # báo lỗi cho client rồi `continue` — theo đúng mẫu `_decode_frame`
            # đã làm cho lỗi giải mã ảnh.
            try:
                # Chạy pose estimation, rồi làm mượt so với frame trước trong
                # CÙNG phiên này — xem docstring KeypointSmoother. Mất người
                # thì smoother tự xoá trạng thái cũ (không nội suy nhầm).
                if input_mode == INPUT_KEYPOINTS:
                    detected = client_keypoints
                else:
                    detected = await _pose_estimator_pool.estimate(jpeg_bytes)
                keypoints = smoother.smooth(detected)
                if keypoints is None:
                    await websocket.send_json({
                        "rep_count": session.rep_counter.rep_count,
                        "errors": ["Không phát hiện được người trong frame."],
                        "correct": False,
                        "key_angles": KeyAngles().model_dump(),
                        "phase": session.rep_counter.phase.value,
                        "keypoints": None,
                        "all_keypoints": None,
                        "similarity_score": None,
                    })
                    continue

                # Phân tích kỹ thuật
                result: FrameAnalysisResult = analyzer.analyze(keypoints)
                session.record_frame(result.errors)

                # Khung xương ĐẦY ĐỦ cho client vẽ (mặt, khuỷu tay, cổ tay...),
                # tách khỏi `result.keypoints` (chỉ những khớp analyzer này
                # thực sự dùng để tính góc) — gán SAU khi analyzer trả về,
                # không analyzer nào cần biết hay sửa gì cho trường này.
                named = named_keypoints(keypoints)
                result.all_keypoints = visible_points(named)
                if scorer is not None:
                    result.similarity_score = scorer.update(named)

                await websocket.send_json(result.model_dump())
            except WebSocketDisconnect:
                raise
            except Exception as exc:
                logger.exception(
                    "Lỗi xử lý MỘT frame (bài '%s') — bỏ qua frame này, phiên vẫn tiếp tục: %s",
                    session.exercise,
                    exc,
                )
                try:
                    await websocket.send_json({"error": "Lỗi xử lý frame này, đã bỏ qua."})
                except Exception:
                    pass
                continue

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
