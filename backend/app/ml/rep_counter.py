"""Đếm số rep theo chu kỳ góc khớp."""

from enum import Enum


class Phase(str, Enum):
    TOP = "top"              # Vị trí đứng thẳng / bắt đầu
    GOING_DOWN = "going_down"
    BOTTOM = "bottom"        # Vị trí thấp nhất
    GOING_UP = "going_up"


class RepCounter:
    """
    Đếm rep dựa trên góc khớp chính (vd: góc gối với squat).

    Một rep hoàn chỉnh: TOP → GOING_DOWN → BOTTOM → GOING_UP → TOP.

    Cải tiến so với phiên bản cũ:
    - Theo dõi góc nhỏ nhất trong lần xuống (_min_angle_seen) để phát hiện
      trường hợp FPS thấp bỏ lỡ frame dưới ngưỡng: nếu góc bắt đầu tăng
      trở lại và min từng thấy < down_threshold + 10°, coi như đã qua BOTTOM.
    - Theo dõi góc frame trước (_prev_angle) để nhận biết đảo chiều.
    """

    # Biên phát hiện "đảo chiều đủ sâu" — nếu min angle thấp hơn ngưỡng này
    # trong khi đang đi xuống và góc bắt đầu tăng ≥ 5°, coi như đã qua đáy.
    _NEAR_BOTTOM_MARGIN = 10.0
    _REVERSAL_MIN_DELTA = 5.0  # Phải tăng ít nhất 5° mới tính là đảo chiều thật

    def __init__(
        self,
        down_threshold: float = 90.0,
        up_threshold: float = 160.0,
    ) -> None:
        self.down_threshold = down_threshold
        self.up_threshold = up_threshold
        self._rep_count: int = 0
        self._phase: Phase = Phase.TOP
        self._prev_angle: float | None = None
        self._min_angle_seen: float = 180.0

    @property
    def rep_count(self) -> int:
        return self._rep_count

    @property
    def phase(self) -> Phase:
        return self._phase

    def update(self, angle: float) -> bool:
        """
        Cập nhật phase theo góc hiện tại.

        Trả True nếu vừa hoàn thành 1 rep trong lần gọi này.
        """
        completed = False
        self._min_angle_seen = min(self._min_angle_seen, angle)

        if self._phase in (Phase.TOP, Phase.GOING_DOWN):
            if angle < self.down_threshold:
                self._phase = Phase.BOTTOM
            else:
                self._phase = Phase.GOING_DOWN
                # Phát hiện đảo chiều: góc đang tăng (đủ lớn để không phải nhiễu)
                # và đã từng xuống gần ngưỡng → coi như đã qua đáy, chuyển GOING_UP.
                # Xử lý trường hợp FPS thấp bỏ lỡ frame dưới down_threshold.
                if (
                    self._prev_angle is not None
                    and angle >= self._prev_angle + self._REVERSAL_MIN_DELTA
                    and self._min_angle_seen < self.down_threshold + self._NEAR_BOTTOM_MARGIN
                ):
                    self._phase = Phase.GOING_UP

        elif self._phase == Phase.BOTTOM:
            if angle > self.down_threshold:
                self._phase = Phase.GOING_UP

        elif self._phase == Phase.GOING_UP:
            if angle > self.up_threshold:
                self._phase = Phase.TOP
                self._rep_count += 1
                self._min_angle_seen = 180.0  # Reset cho rep tiếp theo
                completed = True
            elif angle < self.down_threshold:
                self._phase = Phase.BOTTOM

        self._prev_angle = angle
        return completed

    def reset(self) -> None:
        """Đặt lại bộ đếm về trạng thái ban đầu."""
        self._rep_count = 0
        self._phase = Phase.TOP
        self._prev_angle = None
        self._min_angle_seen = 180.0
