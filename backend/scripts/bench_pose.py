"""Đo hiệu năng MediaPipe (`PoseEstimator`) trên CHÍNH máy chạy script.

Chạy trên VPS để biết server gánh được bao nhiêu người tập cùng lúc khi phải tự
nhận diện tư thế (đường ảnh JPEG dự phòng, APK cũ, và phân tích video upload).
Đường ML Kit trên điện thoại KHÔNG đi qua bước này nên không bị ảnh hưởng.

Cách dùng (từ thư mục backend/, trên VPS cần sudo vì đọc storage của root):

    sudo venv/bin/python scripts/bench_pose.py
    sudo venv/bin/python scripts/bench_pose.py --video storage/exercise_videos/barbell-curl.mp4
    sudo venv/bin/python scripts/bench_pose.py --threads 1,2,3 --frames 90

Cần một video CÓ NGƯỜI: ảnh không có người khiến MediaPipe thoát sớm, cho thời
gian nhanh giả tạo. Script cảnh báo nếu tỉ lệ nhận diện được người quá thấp.

Mỗi luồng dùng một `PoseEstimator` RIÊNG, giống `PoseEstimatorPool` (một
instance MediaPipe không thread-safe).
"""

import argparse
import os
import statistics
import sys
import threading
import time
from pathlib import Path

import cv2

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.ml.pose_estimator import PoseEstimator  # noqa: E402

DEFAULT_VIDEO_DIR = Path(__file__).resolve().parent.parent / "storage" / "exercise_videos"
APP_FPS = 12  # trần fps mà app gửi mỗi người (`_frameInterval` = 80ms)


def percentile(values: list[float], p: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return float("nan")
    index = min(len(ordered) - 1, max(0, round(p / 100 * (len(ordered) - 1))))
    return ordered[index]


def summarize(values: list[float]) -> str:
    return (
        f"trung binh {statistics.fmean(values):6.1f} ms | "
        f"p50 {percentile(values, 50):6.1f} | "
        f"p95 {percentile(values, 95):6.1f} | "
        f"max {max(values):6.1f}"
    )


def load_jpeg_frames(video: Path, count: int, long_side: int) -> list[bytes]:
    cap = cv2.VideoCapture(str(video))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 0
    if total <= 0:
        raise SystemExit(f"Không đọc được video: {video}")
    indices = {int(i * (total - 1) / max(1, count - 1)) for i in range(count)}
    frames: list[bytes] = []
    for idx in range(total):
        ok, frame = cap.read()
        if not ok:
            break
        if idx not in indices:
            continue
        h, w = frame.shape[:2]
        scale = long_side / max(h, w)
        if scale != 1:
            frame = cv2.resize(frame, (round(w * scale), round(h * scale)))
        ok, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
        if ok:
            frames.append(buf.tobytes())
    cap.release()
    if not frames:
        raise SystemExit("Không lấy được frame nào từ video.")
    return frames


def bench_sequential(frames: list[bytes], warmup: int) -> tuple[list[float], int]:
    estimator = PoseEstimator()
    try:
        for i in range(warmup):
            estimator.estimate(frames[i % len(frames)])
        times: list[float] = []
        detected = 0
        for frame in frames:
            t0 = time.perf_counter()
            keypoints = estimator.estimate(frame)
            times.append((time.perf_counter() - t0) * 1000)
            detected += keypoints is not None
        return times, detected
    finally:
        estimator.close()


def bench_threads(frames: list[bytes], threads: int, warmup: int) -> tuple[list[float], float]:
    """Chạy `threads` luồng đồng thời, mỗi luồng xử lý hết `frames`. Trả về thời
    gian từng frame (dưới tranh chấp CPU) và thông lượng tổng (frame/giây)."""
    per_thread: list[list[float]] = [[] for _ in range(threads)]
    ready = threading.Barrier(threads + 1)
    finished_at: list[float] = [0.0] * threads

    def worker(slot: int) -> None:
        estimator = PoseEstimator()
        try:
            for i in range(warmup):
                estimator.estimate(frames[i % len(frames)])
            ready.wait()
            for frame in frames:
                t0 = time.perf_counter()
                estimator.estimate(frame)
                per_thread[slot].append((time.perf_counter() - t0) * 1000)
            finished_at[slot] = time.perf_counter()
        finally:
            estimator.close()

    workers = [threading.Thread(target=worker, args=(i,)) for i in range(threads)]
    for w in workers:
        w.start()
    ready.wait()
    start = time.perf_counter()
    for w in workers:
        w.join()
    wall = max(finished_at) - start
    all_times = [t for slot in per_thread for t in slot]
    return all_times, (threads * len(frames)) / wall


def describe_machine() -> None:
    print(f"CPU: {os.cpu_count()} luong")
    if hasattr(os, "getloadavg"):
        one, five, fifteen = os.getloadavg()
        print(f"Load trung binh truoc khi do (1/5/15 phut): {one:.2f} / {five:.2f} / {fifteen:.2f}")
    meminfo = Path("/proc/meminfo")
    if meminfo.exists():
        info = dict(line.split(":", 1) for line in meminfo.read_text().splitlines() if ":" in line)
        total = int(info["MemTotal"].split()[0]) // 1024
        avail = int(info["MemAvailable"].split()[0]) // 1024
        print(f"RAM: {avail} MB trong / {total} MB tong")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--video", type=Path, help="video có người (mặc định: video đầu tiên trong storage/)")
    parser.add_argument("--frames", type=int, default=60, help="số frame lấy mẫu từ video (mặc định 60)")
    parser.add_argument(
        "--long-side", type=int, default=720, help="cạnh dài của ảnh gửi đi, px (mặc định 720)"
    )
    parser.add_argument(
        "--threads", default=None, help="các mức luồng đồng thời, vd 1,2,3 (mặc định 1..số CPU)"
    )
    parser.add_argument("--warmup", type=int, default=5)
    args = parser.parse_args()

    video = args.video
    if video is None:
        candidates = sorted(DEFAULT_VIDEO_DIR.glob("*.mp4"))
        if not candidates:
            raise SystemExit(f"Không có video trong {DEFAULT_VIDEO_DIR} — dùng --video <đường dẫn>.")
        video = candidates[0]
    cpus = os.cpu_count() or 1
    levels = [int(x) for x in args.threads.split(",")] if args.threads else list(range(1, cpus + 1))

    print("=== MAY ===")
    describe_machine()
    print(
        f"\n=== DU LIEU ===\nvideo: {video}\nlay {args.frames} frame, canh dai {args.long_side}px, JPEG q70"
    )
    frames = load_jpeg_frames(video, args.frames, args.long_side)
    avg_kb = statistics.fmean(len(f) for f in frames) / 1024
    print(f"da lay {len(frames)} frame, trung binh {avg_kb:.0f} KB/frame")

    print("\n=== 1 LUONG (do do tre co ban cua MediaPipe) ===")
    times, detected = bench_sequential(frames, args.warmup)
    print(summarize(times))
    rate = detected / len(frames) * 100
    print(f"nhan dien duoc nguoi: {detected}/{len(frames)} ({rate:.0f}%)")
    if rate < 80:
        print("!! Ti le nhan dien thap: video co the khong co nguoi ro, thoi gian tren KHONG dai dien.")
    single_fps = 1000 / statistics.fmean(times)
    print(f"-> toi da ~{single_fps:.1f} frame/giay tren 1 luong")

    print("\n=== NHIEU LUONG DONG THOI (mo phong nhieu nguoi tap cung luc) ===")
    print(f"{'luong':>5} | {'thong luong':>12} | {'nguoi ~12fps':>13} | do tre moi frame")
    for k in levels:
        all_times, throughput = bench_threads(frames, k, args.warmup)
        users = throughput / APP_FPS
        print(f"{k:>5} | {throughput:>8.1f} fps | {users:>13.1f} | {summarize(all_times)}")

    print(
        "\nDoc ket qua: 'nguoi ~12fps' = thong luong / 12. Do la CAN TREN — chua tinh CPU\n"
        "cho phan con lai cua server (xac thuc, DB, analyzer) va tai cua chinh MediaPipe khi\n"
        "nhieu nguoi cung cho hang doi. Muc dung duoc nen lay khoang 50-70% con so nay."
    )


if __name__ == "__main__":
    main()
