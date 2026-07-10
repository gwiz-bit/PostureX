"""Pose estimation dùng MediaPipe Tasks API (0.10.x+)."""

import logging
from dataclasses import dataclass
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

logger = logging.getLogger(__name__)

DEFAULT_MODEL_PATH = Path(__file__).parent / "models" / "pose_landmarker_full.task"


@dataclass
class Keypoint:
    """Tọa độ chuẩn hóa và độ tin cậy của một điểm khớp."""
    x: float
    y: float
    z: float
    visibility: float


class PoseEstimator:
    """Wrapper MediaPipe PoseLandmarker — khởi tạo 1 lần, tái sử dụng mọi frame."""

    LANDMARK_NAMES = {name: idx for idx, name in enumerate([
        "nose", "left_eye_inner", "left_eye", "left_eye_outer",
        "right_eye_inner", "right_eye", "right_eye_outer",
        "left_ear", "right_ear", "mouth_left", "mouth_right",
        "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
        "left_wrist", "right_wrist", "left_pinky", "right_pinky",
        "left_index", "right_index", "left_thumb", "right_thumb",
        "left_hip", "right_hip", "left_knee", "right_knee",
        "left_ankle", "right_ankle", "left_heel", "right_heel",
        "left_foot_index", "right_foot_index",
    ])}

    def __init__(
        self,
        model_path: str | Path = DEFAULT_MODEL_PATH,
        min_detection_confidence: float = 0.5,
        min_tracking_confidence: float = 0.5,
        model_complexity: int = 1,  # giữ tham số cho tương thích
    ) -> None:
        model_path = Path(model_path)
        if not model_path.exists():
            raise FileNotFoundError(
                f"Model không tìm thấy tại: {model_path}\n"
                "Chạy: python download_models.py"
            )

        base_options = mp_python.BaseOptions(model_asset_path=str(model_path))
        options = mp_vision.PoseLandmarkerOptions(
            base_options=base_options,
            running_mode=mp_vision.RunningMode.IMAGE,
            num_poses=1,
            min_pose_detection_confidence=min_detection_confidence,
            min_pose_presence_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence,
        )
        self._landmarker = mp_vision.PoseLandmarker.create_from_options(options)
        logger.info("PoseEstimator khởi tạo từ model: %s", model_path)

    def estimate(self, frame_bytes: bytes) -> list[Keypoint] | None:
        """Nhận JPEG bytes, trả 33 keypoints hoặc None nếu không phát hiện được."""
        arr = np.frombuffer(frame_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            logger.warning("Không giải mã được frame.")
            return None

        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = self._landmarker.detect(mp_image)

        if not result.pose_landmarks:
            return None

        landmarks = result.pose_landmarks[0]
        return [
            Keypoint(x=lm.x, y=lm.y, z=lm.z, visibility=lm.visibility)
            for lm in landmarks
        ]

    def get(self, keypoints: list[Keypoint], name: str) -> Keypoint | None:
        """Lấy keypoint theo tên, trả None nếu không tồn tại."""
        idx = self.LANDMARK_NAMES.get(name)
        if idx is None or idx >= len(keypoints):
            return None
        return keypoints[idx]

    def close(self) -> None:
        """Giải phóng tài nguyên MediaPipe."""
        self._landmarker.close()

    def __enter__(self) -> "PoseEstimator":
        return self

    def __exit__(self, *_: object) -> None:
        self.close()
