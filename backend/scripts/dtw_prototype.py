"""Giai đoạn A/B — thử nghiệm khả thi DTW so khớp thời gian thực.

CHƯA PHẢI CODE SẢN XUẤT — chỉ để trả lời 2 câu hỏi trước khi viết vào
`routes/realtime.py` thật:
  1) DTW so một chuỗi góc "đang tập" với chuỗi góc tham chiếu có cho ra
     điểm số hợp lý không (tập đúng → điểm cao, tập lệch/nhanh/chậm hơn
     vẫn nhận ra được nhờ đặc tính "co giãn thời gian" của DTW)?
  2) Mỗi lần cập nhật điểm số (mỗi frame mới) tốn bao lâu trên CPU thật
     của VPS — có đủ nhanh để chạy song song với pose estimation
     (ngân sách hiện tại: pose estimation ~30-60ms/frame, xem CLAUDE.md)
     mà không làm rớt FPS không?

Cách đo: dùng `windowed DTW` — không so toàn bộ chuỗi tham chiếu với
toàn bộ chuỗi live (sẽ ngày càng chậm khi live dài ra), mà so một CỬA SỔ
trượt cố định N frame gần nhất của live với TOÀN BỘ chuẩn tham chiếu
(chuẩn chỉ ~60-150 frame, đủ ngắn để so toàn bộ mỗi lần). Đây là hướng
tiếp cận thực tế cho "đang tập dở" chứ không phải so hai video đã quay
xong.

Dùng thuần Python (không cài thêm thư viện `fastdtw`/`dtaidistance` —
muốn biết TRẦN chi phí thật khi không có tối ưu C, vì đây mới la
benchmark khả thi, chưa phải bản sẽ deploy).
"""

import json
import sys
import time
from pathlib import Path

REF_DIR = Path("/home/hiephann/reference_poses")
WINDOW = 30  # ~3 giây ở 10fps lấy mẫu — đủ để thấy một phần rep


def _angle_series(frames: list[dict], joints: tuple[str, str, str], projection: str) -> list[float]:
    sys.path.insert(0, "/opt/posturex/backend")
    from app.ml.angle_utils import calculate_angle, calculate_angle_3d

    fn = calculate_angle if projection == "x/y" else calculate_angle_3d
    out = []
    for f in frames:
        a, b, c = (f[j] for j in joints)

        class P:
            def __init__(self, d):
                self.x, self.y, self.z = d["x"], d["y"], d["z"]

        out.append(fn(P(a), P(b), P(c)))
    return out


def dtw_distance(query: list[float], reference: list[float]) -> float:
    """Subsequence DTW: `query` (cửa sổ live, NGẮN) phải khớp TRỌN VẸN,
    nhưng được phép bắt đầu/kết thúc ở BẤT KỲ ĐIỂM NÀO trong `reference`
    (chuẩn, DÀI hơn) — vì người tập đang ở giữa chừng một rep, cửa sổ
    live chỉ nên so với ĐOẠN chuẩn tương ứng, không phải cả chu kỳ.

    Khác DTW cổ điển (2 đầu cố định) đúng ở điều kiện biên: hàng 0 toàn
    số 0 (không phạt điểm bắt đầu ở đâu trên chuẩn) thay vì hàng 0 tích
    luỹ dần — DTW cổ điển ép query giãn ra khớp hết chiều dài reference,
    cho điểm thấp giả tạo ngay cả khi query khớp hoàn hảo một đoạn ngắn.
    """
    n, m = len(query), len(reference)
    prev = [0.0] * (m + 1)  # hàng 0: bắt đầu ở cột nào của reference cũng free
    for i in range(1, n + 1):
        cur = [float("inf")] * (m + 1)
        for j in range(1, m + 1):
            cost = abs(query[i - 1] - reference[j - 1])
            cur[j] = cost + min(prev[j], cur[j - 1], prev[j - 1])
        prev = cur
    return min(prev[1:]) / n  # kết thúc ở cột nào cũng free; chuẩn hoá theo len(query)


def similarity_score(distance: float, scale_degrees: float = 30.0) -> float:
    """Đổi khoảng cách DTW (độ, càng nhỏ càng giống) sang điểm 0-100 dễ
    hiểu cho người dùng. scale_degrees là "khoảng cách trung bình/frame"
    coi như 0 điểm — 30° chọn tạm vì đó cỡ sai số đáng kể của một khớp."""
    return max(0.0, 100.0 * (1 - distance / scale_degrees))


def main():
    joints = ("left_hip", "left_knee", "left_ankle")
    ref = json.loads((REF_DIR / "bodyweight_squat.json").read_text(encoding="utf-8"))
    ref_series = _angle_series(ref["frames"], joints, ref["projection"])
    print(f"Chuan tham chieu: {len(ref_series)} frame, projection={ref['projection']}")

    # Giả lập "đang tập": chính chuỗi chuẩn đó, cắt qua cửa sổ trượt WINDOW
    # frame — mô phỏng người tập đúng y hệt mẫu (kỳ vọng điểm cao dần).
    times = []
    scores = []
    for end in range(WINDOW, len(ref_series) + 1):
        window = ref_series[end - WINDOW : end]
        t0 = time.perf_counter()
        dist = dtw_distance(window, ref_series)
        elapsed = (time.perf_counter() - t0) * 1000
        times.append(elapsed)
        scores.append(similarity_score(dist))

    print(f"So sanh dung chinh chuan (ky vong diem cao): min={min(scores):.1f} "
          f"max={max(scores):.1f} avg={sum(scores)/len(scores):.1f}")
    print(f"Thoi gian moi lan cap nhat DTW: min={min(times):.2f}ms max={max(times):.2f}ms "
          f"avg={sum(times)/len(times):.2f}ms (window={WINDOW}, chuan_len={len(ref_series)})")

    # Đối chứng: chuỗi ngẫu nhiên/lệch hẳn — kỳ vọng điểm thấp hơn rõ rệt,
    # để chắc chắn điểm số không phải lúc nào cũng cao bất kể input.
    import random
    random.seed(0)
    noisy = [90.0 + random.uniform(-5, 5) for _ in range(WINDOW)]  # đứng yên ở giữa ROM
    dist_noisy = dtw_distance(noisy, ref_series)
    print(f"So sanh voi 'dung yen khong tap' (ky vong diem thap): "
          f"score={similarity_score(dist_noisy):.1f}")


if __name__ == "__main__":
    main()
