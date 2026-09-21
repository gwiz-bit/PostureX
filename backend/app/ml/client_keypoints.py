"""Nhận keypoint do CLIENT tự nhận diện, thay cho ảnh JPEG.

VÌ SAO CÓ
---------
Đường mặc định của `/ws/analyze` là client gửi ảnh JPEG, server chạy MediaPipe
rồi mới phân tích. Cả chuỗi (đổi màu + nén JPEG trên điện thoại, mạng, hàng đợi
pose estimation trên VPS 2 vCPU) làm vòng phản hồi chậm và cộng dồn độ trễ vì
mỗi lúc chỉ có một frame đang bay.

Chế độ `input: "keypoints"` để điện thoại tự chạy pose estimation (ML Kit) rồi
chỉ gửi 33 điểm khớp (~1KB thay cho ~30KB ảnh). Server bỏ qua bước MediaPipe,
nhưng KHÔNG đổi gì ở phần sau: làm mượt, analyzer, đếm rep, chấm điểm giống
bài mẫu đều nhận đúng cùng kiểu `list[Keypoint]` như trước.

ĐỊNH DẠNG MỘT FRAME (text JSON)
-------------------------------
    {"keypoints": [[x, y, z, visibility], ...33 phần tử...]}
    {"keypoints": null}          # client không thấy người trong frame

x, y chuẩn hoá 0..1 theo khung ảnh ĐÃ XOAY THẲNG ĐỨNG (cùng hệ toạ độ với
MediaPipe — gốc ở góc trên trái, x sang phải, y xuống dưới). z cùng thang với
x (âm = gần camera hơn) — NHƯNG client ML Kit hiện luôn gửi z = 0, vì z của ML
Kit đo thực tế sai thang và làm hỏng góc 3D (xem `encodeLandmarks` phía Flutter),
nên mọi góc tính từ keypoint client hiện là 2D. visibility 0..1. Thứ tự 33 khớp theo BlazePose, giống
`PoseEstimator.LANDMARK_NAMES`.
"""

import json
import math

from app.ml.pose_estimator import Keypoint, PoseEstimator

LANDMARK_COUNT = len(PoseEstimator.LANDMARK_NAMES)

# Khớp nằm ngoài khung hình có thể có toạ độ hơi vượt [0, 1] — hợp lệ. Nhưng
# vài đơn vị trở lên chắc chắn là client quên chuẩn hoá (còn ở đơn vị pixel),
# và nếu lọt qua thì analyzer tính ra góc vô nghĩa mà không lỗi nào báo.
_MAX_ABS_COORD = 5.0


def parse_client_keypoints(data: bytes | str) -> list[Keypoint] | None:
    """Giải mã một frame keypoint từ client.

    Trả `None` khi client báo không thấy người (`{"keypoints": null}`) — cùng ý
    nghĩa với `PoseEstimator.estimate` trả `None`. Ném `ValueError` khi dữ liệu
    sai định dạng; người gọi phải trả lỗi cho client (đúng MỘT phản hồi cho
    mỗi frame, client dựa vào đó để ghép cặp gửi/nhận).
    """
    if isinstance(data, bytes):
        try:
            data = data.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("Frame keypoint không phải văn bản UTF-8.") from exc

    try:
        payload = json.loads(data)
    except json.JSONDecodeError as exc:
        raise ValueError("Frame keypoint không phải JSON hợp lệ.") from exc

    if not isinstance(payload, dict) or "keypoints" not in payload:
        raise ValueError("Thiếu trường 'keypoints'.")

    raw = payload["keypoints"]
    if raw is None:
        return None
    if not isinstance(raw, list) or len(raw) != LANDMARK_COUNT:
        raise ValueError(f"'keypoints' phải có đúng {LANDMARK_COUNT} khớp.")

    keypoints: list[Keypoint] = []
    for index, item in enumerate(raw):
        if not isinstance(item, list) or len(item) != 4:
            raise ValueError(f"Khớp {index} phải là [x, y, z, visibility].")
        if not all(
            isinstance(v, (int, float)) and not isinstance(v, bool) and math.isfinite(v) for v in item
        ):
            raise ValueError(f"Khớp {index} có giá trị không phải số hữu hạn.")
        x, y, z, visibility = (float(v) for v in item)
        if max(abs(x), abs(y), abs(z)) > _MAX_ABS_COORD:
            raise ValueError(f"Khớp {index} có toạ độ quá lớn — toạ độ phải chuẩn hoá về 0..1.")
        keypoints.append(Keypoint(x=x, y=y, z=z, visibility=min(1.0, max(0.0, visibility))))
    return keypoints
