"""Đo độ trễ ĐẦU-CUỐI của WebSocket `/api/v1/ws/analyze` — đúng đường mà app đi.

Chạy từ máy bất kỳ (máy Windows của bạn, hoặc chính VPS để loại bỏ độ trễ mạng)
mà KHÔNG cần điện thoại. Mô phỏng một hoặc nhiều người tập: mỗi người gửi frame
rồi chờ phản hồi mới gửi tiếp, tối đa ~12 fps — giống hệt `_frameInterval` của app.

    # Đường ML Kit (điện thoại gửi toạ độ, ~1KB/frame) — server chỉ phân tích:
    python scripts/bench_ws.py --mode keypoints

    # Đường ảnh JPEG (server chạy MediaPipe) — cần video CÓ NGƯỜI:
    python scripts/bench_ws.py --mode image --video storage/exercise_videos/barbell-curl.mp4

    # Nhiều người cùng lúc:
    python scripts/bench_ws.py --mode keypoints --users 5

Đăng nhập bằng tài khoản thật. ĐỪNG gõ mật khẩu vào dòng lệnh (nằm trong lịch sử
shell): đặt biến môi trường BENCH_EMAIL và BENCH_PASSWORD, hoặc để script hỏi.

    PowerShell:  $env:BENCH_EMAIL="a@b.com"; $env:BENCH_PASSWORD="..."
"""

import argparse
import asyncio
import base64
import getpass
import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import websockets

DEFAULT_URL = "http://103.82.21.150:9000"
FRAME_INTERVAL_S = 0.08  # ~12 fps — trùng `_frameInterval` của app


def percentile(values: list[float], p: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return float("nan")
    index = min(len(ordered) - 1, max(0, round(p / 100 * (len(ordered) - 1))))
    return ordered[index]


def login(base_url: str, email: str, password: str) -> str:
    request = urllib.request.Request(
        f"{base_url}/api/v1/auth/login",
        data=json.dumps({"email": email, "password": password}).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)["access_token"]
    except urllib.error.HTTPError as exc:
        raise SystemExit(
            f"Đăng nhập thất bại ({exc.code}): {exc.read().decode(errors='replace')[:200]}"
        ) from exc


def synthetic_keypoints() -> list[list[float]]:
    """33 khớp của một người đứng thẳng — chỉ để đo độ trễ, không cần đúng giải
    phẫu. Thứ tự BlazePose; x, y chuẩn hoá theo khung ảnh."""
    pose = [[0.5, 0.5, 0.0, 0.95] for _ in range(33)]
    placements = {
        0: (0.50, 0.12),
        11: (0.42, 0.25),
        12: (0.58, 0.25),
        13: (0.38, 0.38),
        14: (0.62, 0.38),
        15: (0.36, 0.50),
        16: (0.64, 0.50),
        23: (0.45, 0.52),
        24: (0.55, 0.52),
        25: (0.45, 0.72),
        26: (0.55, 0.72),
        27: (0.45, 0.92),
        28: (0.55, 0.92),
        29: (0.44, 0.95),
        30: (0.56, 0.95),
        31: (0.47, 0.96),
        32: (0.53, 0.96),
    }
    for index, (x, y) in placements.items():
        pose[index] = [x, y, 0.0, 0.95]
    return pose


def load_jpeg_frames(video: Path, count: int, long_side: int) -> list[bytes]:
    import cv2  # chỉ cần ở chế độ image

    cap = cv2.VideoCapture(str(video))
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT)) or 0
    if total <= 0:
        raise SystemExit(f"Không đọc được video: {video}")
    wanted = {int(i * (total - 1) / max(1, count - 1)) for i in range(count)}
    frames: list[bytes] = []
    for idx in range(total):
        ok, frame = cap.read()
        if not ok:
            break
        if idx not in wanted:
            continue
        h, w = frame.shape[:2]
        scale = long_side / max(h, w)
        frame = cv2.resize(frame, (round(w * scale), round(h * scale)))
        ok, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
        if ok:
            frames.append(buf.tobytes())
    cap.release()
    if not frames:
        raise SystemExit("Không lấy được frame nào từ video.")
    return frames


async def run_user(
    user: int, ws_url: str, token: str, exercise: str, mode: str, payloads: list[str], frames: int
) -> dict:
    rtts: list[float] = []
    errors = 0
    async with websockets.connect(f"{ws_url}?token={token}", max_size=None) as ws:
        await ws.send(json.dumps({"exercise": exercise, "input": mode}))
        ready = json.loads(await ws.recv())
        if "error" in ready:
            raise SystemExit(f"Server từ chối phiên: {ready['error']}")
        if ready.get("input") != mode:
            print(
                f"[người {user}] cảnh báo: server xác nhận input={ready.get('input')!r}, không phải {mode!r}"
            )

        for i in range(frames):
            started = time.perf_counter()
            await ws.send(payloads[i % len(payloads)])
            reply = json.loads(await ws.recv())
            rtt = (time.perf_counter() - started) * 1000
            if "error" in reply:
                errors += 1
            else:
                rtts.append(rtt)
            # Giữ nhịp tối đa ~12 fps như app: chỉ chờ thêm nếu phản hồi nhanh hơn khung.
            await asyncio.sleep(max(0.0, FRAME_INTERVAL_S - (time.perf_counter() - started)))
    return {"rtts": rtts, "errors": errors}


def report(label: str, rtts: list[float], errors: int, wall_s: float, frames_sent: int) -> None:
    if not rtts:
        print(f"{label}: không có phản hồi hợp lệ nào (lỗi: {errors})")
        return
    over = sum(1 for r in rtts if r > 500) / len(rtts) * 100
    print(
        f"{label}: TB {statistics.fmean(rtts):6.1f} ms | p50 {percentile(rtts, 50):6.1f} | "
        f"p95 {percentile(rtts, 95):6.1f} | p99 {percentile(rtts, 99):6.1f} | max {max(rtts):6.1f} | "
        f"~{len(rtts) / wall_s:4.1f} fps thuc te | >500ms: {over:.1f}% | loi: {errors}/{frames_sent}"
    )


async def main_async(args: argparse.Namespace) -> None:
    base = args.url.rstrip("/")
    ws_url = base.replace("https://", "wss://").replace("http://", "ws://") + "/api/v1/ws/analyze"

    email = args.email or os.environ.get("BENCH_EMAIL") or input("Email: ")
    password = args.password or os.environ.get("BENCH_PASSWORD") or getpass.getpass("Mật khẩu: ")
    token = login(base, email, password)
    print(f"Đã đăng nhập. Server: {base} | chế độ: {args.mode} | {args.users} người × {args.frames} frame\n")

    if args.mode == "keypoints":
        payloads = [json.dumps({"keypoints": synthetic_keypoints(), "aspect": 0.667})]
    else:
        if not args.video:
            raise SystemExit("Chế độ image cần --video có người (ảnh trống sẽ cho kết quả nhanh giả tạo).")
        payloads = [base64.b64encode(f).decode() for f in load_jpeg_frames(args.video, 30, args.long_side)]
        print(f"ảnh trung bình {statistics.fmean(len(p) for p in payloads) * 0.75 / 1024:.0f} KB/frame\n")

    started = time.perf_counter()
    results = await asyncio.gather(
        *(
            run_user(u, ws_url, token, args.exercise, args.mode, payloads, args.frames)
            for u in range(args.users)
        )
    )
    wall = time.perf_counter() - started

    if args.users > 1:
        for u, r in enumerate(results):
            report(f"người {u + 1}", r["rtts"], r["errors"], wall, args.frames)
        print()
    all_rtts = [x for r in results for x in r["rtts"]]
    report("TỔNG   ", all_rtts, sum(r["errors"] for r in results), wall, args.users * args.frames)

    print(
        "\nĐọc kết quả: mục tiêu là p95 dưới ~150 ms và không có frame >500 ms (trên 500 ms app coi\n"
        "là frame rớt). Chạy lại từ chính VPS (--url http://localhost:9000) để tách độ trễ MẠNG\n"
        "khỏi độ trễ SERVER: hiệu số giữa hai lần chạy chính là chi phí mạng."
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--url", default=DEFAULT_URL)
    parser.add_argument("--mode", choices=["keypoints", "image"], default="keypoints")
    parser.add_argument("--exercise", default="bodyweight squat")
    parser.add_argument("--frames", type=int, default=200, help="số frame mỗi người (mặc định 200 ≈ 17 giây)")
    parser.add_argument("--users", type=int, default=1, help="số người tập giả lập đồng thời")
    parser.add_argument("--video", type=Path, help="video có người (chế độ image)")
    parser.add_argument("--long-side", type=int, default=720)
    parser.add_argument("--email")
    parser.add_argument("--password", help="tránh dùng — hãy dùng biến môi trường BENCH_PASSWORD")
    args = parser.parse_args()
    try:
        asyncio.run(main_async(args))
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()
