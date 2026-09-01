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
        # Tín hiệu CHỈ ĐÚNG TRONG FRAME HIỆN TẠI: người tập vừa đảo chiều đi
        # lên mà chưa từng xuống gần đáy — tức một nhịp hụt, không được tính
        # rep. Analyzer đọc cờ này để cảnh báo đúng một lần vào đúng lúc, thay
        # vì tự suy từ phase (xem chú thích ở `update`).
        self._shallow_reversal: bool = False
        # Đối xứng với `_shallow_reversal` nhưng cho đầu trên: người tập quay
        # đầu đi xuống khi chưa duỗi hết ở đỉnh. Cần `_max_angle_seen` riêng vì
        # `_min_angle_seen` chỉ theo dõi đầu dưới.
        self._incomplete_lockout: bool = False
        self._max_angle_seen: float = 0.0

    @property
    def rep_count(self) -> int:
        return self._rep_count

    @property
    def phase(self) -> Phase:
        return self._phase

    @property
    def shallow_reversal(self) -> bool:
        """Frame này người tập có đảo chiều đi lên khi chưa xuống đủ sâu không.

        Chỉ đúng cho frame vừa xử lý, tự tắt ở lần `update` kế tiếp.
        """
        return self._shallow_reversal

    @property
    def incomplete_lockout(self) -> bool:
        """Frame này người tập có hạ xuống khi chưa duỗi hết ở đỉnh không.

        Chỉ đúng cho frame vừa xử lý, tự tắt ở lần `update` kế tiếp.
        """
        return self._incomplete_lockout

    @property
    def min_angle_seen(self) -> float:
        """Góc nhỏ nhất đã đạt trong nhịp hiện tại (để analyzer chấm độ sâu)."""
        return self._min_angle_seen

    def update(self, angle: float) -> bool:
        """
        Cập nhật phase theo góc hiện tại.

        Trả True nếu vừa hoàn thành 1 rep trong lần gọi này.
        """
        completed = False
        self._shallow_reversal = False
        self._incomplete_lockout = False
        self._min_angle_seen = min(self._min_angle_seen, angle)
        self._max_angle_seen = max(self._max_angle_seen, angle)

        if self._phase in (Phase.TOP, Phase.GOING_DOWN):
            if angle < self.down_threshold:
                # Chạm đáy → đếm rep ngay lập tức
                self._phase = Phase.BOTTOM
                self._rep_count += 1
                self._min_angle_seen = 180.0  # reset cho rep tiếp theo
                # Bắt đầu một lần đi lên mới: quên đỉnh của nhịp trước, nếu
                # không thì lần khoá khớp cũ che mất lần này.
                self._max_angle_seen = angle
                completed = True
            else:
                self._phase = Phase.GOING_DOWN
                # Fallback FPS thấp: bỏ lỡ frame dưới ngưỡng nhưng góc
                # đã từng gần đáy và đang tăng → coi như đã chạm đáy.
                reversed_upward = (
                    self._prev_angle is not None
                    and angle >= self._prev_angle + self._REVERSAL_MIN_DELTA
                )
                # Phải THẬT SỰ đã hạ xuống mới xét là đảo chiều. Thiếu vế này
                # thì mấy frame cuối lúc đứng lên (góc vẫn đang tăng, đáy cũ đã
                # bị xoá khi về TOP) cũng bị coi là "đi lên mà chưa xuống sâu"
                # và báo lỗi oan cho một rep hoàn hảo.
                descended = self._min_angle_seen < self.up_threshold
                if reversed_upward and descended:
                    if self._min_angle_seen < self.down_threshold + self._NEAR_BOTTOM_MARGIN:
                        self._phase = Phase.GOING_UP
                        self._rep_count += 1
                        self._max_angle_seen = angle
                        completed = True
                    else:
                        # Đi lên mà chưa từng xuống gần đáy → nhịp hụt: không
                        # tính rep, chỉ báo cho analyzer nhắc người tập.
                        self._shallow_reversal = True
                    # Xoá đáy của nhịp vừa kết thúc trong cả hai trường hợp,
                    # nếu không những frame đi lên tiếp theo sẽ lặp lại chính
                    # kết luận đó (rep đếm thêm, hoặc nhắc lại nhiều lần).
                    self._min_angle_seen = 180.0

        elif self._phase == Phase.BOTTOM:
            if angle > self.down_threshold:
                self._phase = Phase.GOING_UP

        elif self._phase == Phase.GOING_UP:
            # Quay đầu đi xuống khi đỉnh cao nhất của lần lên này còn chưa tới
            # `up_threshold` → chưa duỗi hết đã hạ. Kiểm ở đây thay vì kiểu cũ
            # `phase == "top" and angle < up_threshold`: điều kiện đó tự mâu
            # thuẫn, vì phase chỉ thành TOP đúng lúc angle vượt up_threshold —
            # nên cảnh báo "chưa duỗi hết ở đỉnh" của deadlift/hip thrust/
            # overhead press chưa từng chạy lần nào.
            if (
                self._prev_angle is not None
                and angle <= self._prev_angle - self._REVERSAL_MIN_DELTA
                and self._max_angle_seen < self.up_threshold
            ):
                self._incomplete_lockout = True
                self._max_angle_seen = angle
                # Đã quay đầu đi xuống thì coi như đang xuống — vừa đúng thực
                # tế, vừa để những frame hạ tiếp theo không lặp lại cùng một
                # lời nhắc.
                self._phase = Phase.GOING_DOWN

            # Phải đứng thẳng lại đến up_threshold mới sẵn sàng cho rep mới
            if angle > self.up_threshold:
                self._phase = Phase.TOP
                # Xoá đáy của nhịp vừa xong. Thiếu dòng này thì `_min_angle_seen`
                # còn giữ ~85° của rep trước, và ngay frame kế tiếp — vẫn đang
                # đứng lên nên góc còn tăng ≥5° — nhánh fallback FPS thấp ở trên
                # tưởng nhầm là vừa chạm đáy lần nữa và đếm thêm một rep cho
                # cùng một lần xuống. Hậu quả: mọi bài tập đếm gấp đôi ở tốc độ
                # tập thông thường (đo được: 10 rep thật -> 20).
                self._min_angle_seen = 180.0
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
