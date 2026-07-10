"""Tải model MediaPipe PoseLandmarker về thư mục app/ml/models/."""

import urllib.request
from pathlib import Path

MODEL_URL = (
    "https://storage.googleapis.com/mediapipe-models/"
    "pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task"
)
MODEL_PATH = Path("app/ml/models/pose_landmarker_full.task")


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading model from:\n  {url}")
    print(f"Saving to: {dest}")

    def progress(block_num: int, block_size: int, total_size: int) -> None:
        downloaded = block_num * block_size
        if total_size > 0:
            pct = min(downloaded / total_size * 100, 100)
            bar = "#" * int(pct // 2)
            print(f"\r  [{bar:<50}] {pct:.1f}%", end="", flush=True)

    urllib.request.urlretrieve(url, dest, reporthook=progress)
    print(f"\nDone! ({dest.stat().st_size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    if MODEL_PATH.exists():
        print(f"Model already exists: {MODEL_PATH}")
    else:
        download(MODEL_URL, MODEL_PATH)
