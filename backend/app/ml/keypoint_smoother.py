"""Làm mượt toạ độ khớp giữa các frame liên tiếp trong CÙNG một phiên.

VÌ SAO CẦN
----------
`PoseEstimator` chạy MediaPipe ở `RunningMode.IMAGE` (xem `pose_estimator.py`)
— mỗi frame được nhận diện HOÀN TOÀN ĐỘC LẬP, không có ngữ cảnh thời gian từ
frame trước. Với `RunningMode.VIDEO`/`LIVE_STREAM`, MediaPipe tự làm mượt nội
bộ giữa các frame liên tiếp — nhưng hai chế độ đó giả định một luồng frame
LIÊN TỤC của cùng một người, trong khi `PoseEstimatorPool` (xem
`pose_estimator_pool.py`) cố tình để một instance MediaPipe phục vụ xen kẽ
NHIỀU phiên tập khác nhau (mỗi lúc một luồng, tối đa hoá dùng chung CPU).
Trộn hai điều này sẽ làm hỏng bộ làm mượt nội bộ của MediaPipe — nó sẽ tưởng
nhầm frame của người khác là "frame tiếp theo" của cùng một người, không chỉ
vô ích mà còn tạo ảnh giả (smoothing artifact). Đổi đúng cách cần thiết kế
lại cả pool cho gắn instance riêng theo từng phiên — việc lớn, để dành sau.

Class này làm mượt Ở TẦNG ỨNG DỤNG thay vì tầng MediaPipe: rẻ, không đụng
pool, và mỗi phiên/video giữ trạng thái làm mượt RIÊNG (một instance mới cho
mỗi WebSocket session hoặc mỗi video upload) nên không có rủi ro trộn người
như trên.

Xác nhận thực tế 09/09/2026: test trên điện thoại thật thấy khung xương
"nhảy loạn" — không cố định một hướng (loại trừ được lỗi toạ độ/crop), mà
lúc lệch lúc không tuỳ frame — đúng triệu chứng thiếu làm mượt thời gian.
"""

from app.ml.pose_estimator import Keypoint


class KeypointSmoother:
    """Trung bình trượt hàm mũ (EMA) trên toạ độ x/y/z, giữ trạng thái theo
    từng instance — tạo MỘT instance riêng cho mỗi phiên WebSocket hoặc mỗi
    video, không dùng chung giữa các phiên.

    `alpha` càng gần 1 thì càng bám sát frame mới (ít mượt, ít lag); càng
    gần 0 thì càng mượt nhưng khung xương trễ hơn so với chuyển động thật.
    0.5 là ước lượng ban đầu cân bằng hai điều đó — CHƯA đo trên người thật
    xem có cần chỉnh không, cùng tình trạng với ngưỡng góc của các analyzer
    mới (xem CHANGELOG 06/09/2026).
    """

    def __init__(self, alpha: float = 0.5) -> None:
        if not 0.0 < alpha <= 1.0:
            raise ValueError(f"alpha phải trong khoảng (0, 1], nhận {alpha}")
        self._alpha = alpha
        self._prev: list[Keypoint] | None = None

    def smooth(self, keypoints: list[Keypoint] | None) -> list[Keypoint] | None:
        """Làm mượt một frame keypoint mới, cập nhật trạng thái nội bộ.

        Mất người (`None`) hoặc số khớp đổi khác thì XOÁ trạng thái cũ thay
        vì cố nội suy — nối một tư thế mới với vị trí của một tư thế/người
        trước đó (có thể đã rời khung hình) sẽ tạo chuyển động giả, tệ hơn
        cả việc không làm mượt.
        """
        if keypoints is None:
            self._prev = None
            return None

        prev = self._prev
        if prev is None or len(prev) != len(keypoints):
            self._prev = keypoints
            return keypoints

        a = self._alpha
        smoothed = [
            Keypoint(
                x=a * new.x + (1 - a) * old.x,
                y=a * new.y + (1 - a) * old.y,
                z=a * new.z + (1 - a) * old.z,
                # Độ tin cậy giữ nguyên của frame MỚI, không làm mượt — đây
                # là tín hiệu "khớp này có đang thấy rõ không" tại đúng thời
                # điểm hiện tại, làm mượt nó sẽ khiến is_visible() phản ứng
                # trễ (vd tay vừa ra khỏi khung hình nhưng vẫn coi là "thấy"
                # thêm vài frame vì độ tin cậy cũ còn cao).
                visibility=new.visibility,
            )
            for new, old in zip(keypoints, prev, strict=True)
        ]
        self._prev = smoothed
        return smoothed
