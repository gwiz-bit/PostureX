"""Đếm số rep theo chu kỳ góc khớp."""

from enum import Enum


class Phase(str, Enum):
    TOP = "top"              # Vị trí đứng thẳng / bắt đầu
    GOING_DOWN = "going_down"
    BOTTOM = "bottom"        # Vị trí thấp nhất — rep được tính tại đây
    GOING_UP = "going_up"


class RepCounter:
    """
    Đếm rep dựa trên góc khớp chính (vd: góc gối với squat).

    Rep được tính ngay khi góc xuống dưới down_threshold (chạm đáy),
    không phải khi đứng thẳng trở lại. Chu kỳ:
        TOP → GOING_DOWN → BOTTOM (đếm rep) → GOING_UP → TOP

    Người dùng phải đứng thẳng lại (đạt up_threshold) trước khi rep
    tiếp theo được tính, tránh đếm nhiều lần khi ngồi yên ở đáy.

    Fallback FPS thấp: nếu frame dưới ngưỡng bị bỏ lỡ nhưng góc đã
    từng gần ngưỡng và bắt đầu tăng trở lại ≥ 5°, vẫn tính là 1 rep.
    """

    _NEAR_BOTTOM_MARGIN = 10.0  # Biên "gần đáy": down_threshold + 10°
    _REVERSAL_MIN_DELTA = 5.0   # Tăng ít nhất 5° mới coi là đảo chiều thật

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
                # Chạm đáy → đếm rep ngay lập tức
                self._phase = Phase.BOTTOM
                self._rep_count += 1
                self._min_angle_seen = 180.0  # reset cho rep tiếp theo
                completed = True
            else:
                self._phase = Phase.GOING_DOWN
                # Fallback FPS thấp: bỏ lỡ frame dưới ngưỡng nhưng góc
                # đã từng gần đáy và đang tăng → coi như đã chạm đáy.
                if (
                    self._prev_angle is not None
                    and angle >= self._prev_angle + self._REVERSAL_MIN_DELTA
                    and self._min_angle_seen < self.down_threshold + self._NEAR_BOTTOM_MARGIN
                ):
                    self._phase = Phase.GOING_UP
                    self._rep_count += 1
                    self._min_angle_seen = 180.0
                    completed = True

        elif self._phase == Phase.BOTTOM:
            if angle > self.down_threshold:
                self._phase = Phase.GOING_UP

        elif self._phase == Phase.GOING_UP:
            # Phải đứng thẳng lại đến up_threshold mới sẵn sàng cho rep mới
            if angle > self.up_threshold:
                self._phase = Phase.TOP
            elif angle < self.down_threshold:
                # Ngồi xuống lại mà chưa đứng thẳng hẳn → về BOTTOM, không đếm
                self._phase = Phase.BOTTOM

        self._prev_angle = angle
        return completed

    def reset(self) -> None:
        """Đặt lại bộ đếm về trạng thái ban đầu."""
        self._rep_count = 0
        self._phase = Phase.TOP
        self._prev_angle = None
        self._min_angle_seen = 180.0
