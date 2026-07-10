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
    """

    def __init__(
        self,
        down_threshold: float = 90.0,   # Góc nhỏ hơn ngưỡng này => đã xuống đủ sâu
        up_threshold: float = 160.0,    # Góc lớn hơn ngưỡng này => đã đứng thẳng
    ) -> None:
        self.down_threshold = down_threshold
        self.up_threshold = up_threshold
        self._rep_count: int = 0
        self._phase: Phase = Phase.TOP

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

        if self._phase in (Phase.TOP, Phase.GOING_DOWN):
            if angle < self.down_threshold:
                self._phase = Phase.BOTTOM
            else:
                self._phase = Phase.GOING_DOWN

        elif self._phase == Phase.BOTTOM:
            if angle > self.down_threshold:
                self._phase = Phase.GOING_UP

        elif self._phase == Phase.GOING_UP:
            if angle > self.up_threshold:
                self._phase = Phase.TOP
                self._rep_count += 1
                completed = True
            elif angle < self.down_threshold:
                # Người dùng xuống lại mà chưa đứng thẳng
                self._phase = Phase.BOTTOM

        return completed

    def reset(self) -> None:
        """Đặt lại bộ đếm về trạng thái ban đầu."""
        self._rep_count = 0
        self._phase = Phase.TOP
