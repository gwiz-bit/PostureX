"""Test trực tiếp `RepCounter` bằng chuỗi góc thô — không qua analyzer/pose,
vì bug nằm ngay trong máy trạng thái dùng chung, không phải ở cách một
analyzer cụ thể đọc kết quả.

Phát hiện 17/09/2026 lúc rà toàn bộ lõi real-time theo yêu cầu audit: một
rep thật có "khựng" nhẹ giữa chừng lúc duỗi lên (chưa duỗi hết đã hạ xuống
lại rồi lại đi lên tiếp — rất dễ xảy ra thật, không phải tình huống hiếm) bị
đếm thành 2 rep. Đây là TÁI PHÁT của đúng lớp lỗi đã sửa 01/09/2026 (rep bị
đếm gấp đôi), qua một đường khác: `incomplete_lockout` (thêm sau, cùng ngày
01/09) reset `_max_angle_seen` nhưng quên reset `_min_angle_seen` — nên khi
quay lại nhánh (TOP, GOING_DOWN), dữ liệu "đã từng gần đáy" của LẦN ĐI LÊN
TRƯỚC đó (không phải của cú khựng vừa rồi) vẫn còn, khiến nhánh dự phòng FPS
thấp tưởng nhầm cú khựng là một lần chạm đáy mới.

Cùng đợt sửa: `shallow_reversal` (nhịp hụt, không tính rep) không chuyển
phase ra khỏi (TOP, GOING_DOWN) — nên nếu người tập tiếp tục đi lên sau nhịp
hụt, `descended` luôn đúng lại ngay ở frame kế tiếp (vì `_min_angle_seen` đã
reset về 180 rồi lập tức được gán lại đúng bằng góc frame đó, luôn < up_
threshold khi còn đang đi lên) — bắn `shallow_reversal` liên tục mỗi frame
cho tới khi vượt hẳn `up_threshold`, và `incomplete_lockout` (chỉ chạy ở
phase GOING_UP) bị vô hiệu hoá suốt quãng bị kẹt đó.
"""

from app.ml.rep_counter import Phase, RepCounter


def test_khung_giua_chung_khi_duoi_len_khong_bi_dem_thanh_2_rep():
    """Mô phỏng đúng kịch bản deadlift phát hiện lúc audit: chạm đáy thật
    (1 rep), đi lên, khựng nhẹ chưa duỗi hết (incomplete_lockout), rồi đi
    lên tiếp và duỗi hết hẳn — phải là ĐÚNG 1 rep, không phải 2."""
    counter = RepCounter(down_threshold=110.0, up_threshold=165.0)

    # Chạm đáy thật -> 1 rep.
    for angle in (170.0, 140.0, 105.0):
        counter.update(angle)
    assert counter.rep_count == 1
    assert counter.phase == Phase.BOTTOM

    counter.update(115.0)  # BOTTOM -> GOING_UP
    assert counter.phase == Phase.GOING_UP

    counter.update(140.0)
    counter.update(150.0)  # đang duỗi lên, chưa tới up_threshold

    # Khựng nhẹ: hạ xuống 5° đúng lúc max_angle_seen (150) < up_threshold (165)
    # -> incomplete_lockout, KHÔNG phải một lần chạm đáy mới.
    counter.update(145.0)
    assert counter.incomplete_lockout is True
    assert counter.phase == Phase.GOING_DOWN

    # Đi lên tiếp và duỗi hết hẳn — đây vẫn là CÙNG một rep đã đếm ở trên.
    counter.update(152.0)
    counter.update(170.0)

    assert counter.rep_count == 1, (
        f"Bug tái phát 01/09/2026: rep_count={counter.rep_count}, "
        "cú khựng giữa chừng lúc duỗi lên bị đếm thành rep thứ 2."
    )


def test_nhip_hut_khong_bi_bao_lap_lai_nhieu_lan_va_phase_thoat_duoc_going_down():
    """Một nhịp hụt (không xuống đủ sâu) đi lên liên tục qua nhiều frame chỉ
    được báo `shallow_reversal` ĐÚNG MỘT LẦN, và phase phải thoát khỏi
    GOING_DOWN khi thực sự đã đứng thẳng lại — không bị kẹt vĩnh viễn."""
    counter = RepCounter(down_threshold=110.0, up_threshold=165.0)

    counter.update(170.0)  # TOP

    # Xuống hụt, chỉ tới 125° (không chạm 110°).
    counter.update(150.0)
    counter.update(125.0)

    # Đi lên liên tục qua nhiều frame, chưa vượt up_threshold ở 3 frame đầu.
    shallow_flags = []
    for angle in (132.0, 142.0, 155.0):
        counter.update(angle)
        shallow_flags.append(counter.shallow_reversal)

    assert shallow_flags.count(True) == 1, (
        f"shallow_reversal bắn {shallow_flags.count(True)} lần cho 1 nhịp hụt "
        f"duy nhất: {shallow_flags} — sẽ đọc TTS nhắc lỗi lặp lại nhiều lần."
    )

    # Vượt hẳn up_threshold -> phải về TOP, không được kẹt ở GOING_DOWN.
    counter.update(168.0)
    assert counter.phase == Phase.TOP, (
        f"phase={counter.phase} — kẹt ở GOING_DOWN dù đã đứng thẳng hẳn lại."
    )
    assert counter.rep_count == 0
