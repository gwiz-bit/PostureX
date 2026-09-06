"""Ngưỡng nào của bài tập nào là chỉnh được — siêu dữ liệu cho màn admin.

VÌ SAO CẦN FILE NÀY
-------------------
Màn admin "AI Config" trước đây ghi cứng đúng 5 thanh trượt cho squat. Cách
đó sai theo hai hướng cùng lúc: 8 analyzer còn lại không chỉnh được gì, mà
squat lại lộ ra cả những ô không có tác dụng (xem phần dưới).

Bảng này là nguồn sự thật duy nhất cho câu hỏi "bài này chỉnh được gì". Cả
API admin lẫn giao diện đều đọc từ đây, nên thêm một ngưỡng mới cho analyzer
chỉ phải khai đúng một chỗ — không phải sửa song song backend và Flutter rồi
quên mất một bên.

BỐN Ô ĐIỀU KHIỂN CŨ KHÔNG CÓ TÁC DỤNG
--------------------------------------
Trước khi viết lại, đã kiểm từng ô trên màn hình cũ. Chỉ 3 trong 7 thật sự
thay đổi hành vi phân tích:

- `squat_rep_down_threshold` — trùng `knee_depth`. `squat.py` xây RepCounter
  bằng `down_threshold=t.get("knee_depth", ...)`, nên hai ô đó vốn là một số;
  handler PATCH lại chỉ áp ô kia, nên kéo thanh này không đổi gì.
- `squat_rep_up_threshold` — handler không bao giờ đọc tới. Giá trị thật là
  `stand_up_min`, ghi cứng 155.0 trong `squat.py`.
- `pose_min_detection_confidence` và `pose_model_complexity` — pool ước lượng
  tư thế được dựng ở cấp module (`realtime.py`: `PoseEstimatorPool(...)`) ngay
  lúc import, nên giá trị admin nhập không có đường nào tới nó. Riêng
  `model_complexity` còn vô nghĩa ở tầng thấp hơn: MediaPipe Tasks API chọn độ
  phức tạp theo FILE model, tham số chỉ còn giữ cho tương thích.

Hai ô pose không được đưa vào đây, vì chúng là cấu hình toàn cục của một pool
tạo sẵn lúc khởi động — muốn chỉnh được thật thì phải dựng lại pool giữa
chừng, việc đó nằm ngoài phạm vi "ngưỡng theo từng bài tập".

KHOÁ PHẢI KHỚP `VALUE_COLUMN`
-----------------------------
`key` ở đây phải là khoá có trong `thresholds.VALUE_COLUMN`, vì đó là thứ
quyết định giá trị được ghi vào cột `MinAngle` hay `MaxAngle`. Sai khoá thì
ngưỡng được lưu xuống bình thường rồi bị bỏ qua trong im lặng lúc chạy —
`test_tunables.py` khoá lại điều kiện này.
"""

from dataclasses import dataclass

from app.ml.analyzers.thresholds import VALUE_COLUMN


@dataclass(frozen=True)
class Tunable:
    """Một ngưỡng chỉnh được, kèm đủ thông tin để giao diện tự dựng ô nhập."""

    key: str
    label: str
    default: float
    minimum: float
    maximum: float

    #: Ngưỡng đếm rep — đổi nó là đổi luôn cách đếm, không chỉ cách chấm điểm.
    #: Giao diện dùng cờ này để cảnh báo admin.
    affects_rep_count: bool = False

    #: Đơn vị hiển thị. Gần hết là độ, riêng `knee_overshoot` là tỉ lệ theo
    #: chiều rộng frame nên để rỗng — hiện "0.05°" sẽ khiến admin hiểu sai
    #: hoàn toàn thứ mình đang chỉnh.
    unit: str = "°"

    #: Bước nhảy của thanh trượt. Với góc, dưới 1° không có ý nghĩa thực tế
    #: (`RepCounter` còn biên dung sai 10° quanh đáy). Với tỉ lệ thì 1 đơn vị
    #: là cả khung hình, nên phải nhỏ hơn nhiều.
    step: float = 1.0


# Biên min/max dưới đây là khoảng HỢP LỆ để nhập, không phải khuyến nghị.
# Đặt rộng có chủ đích: chúng chỉ chặn giá trị vô nghĩa (gối gập 5°, lưng
# thẳng 300°), còn việc con số nào đúng cho một biến thể cụ thể thì phải đo
# trên người thật chứ không suy ra được ở đây.
TUNABLES: dict[str, list[Tunable]] = {
    "SquatAnalyzer": [
        Tunable("knee_depth", "Độ sâu gối — gập dưới góc này mới tính đủ sâu",
                95.0, 40.0, 140.0, affects_rep_count=True),
        Tunable("stand_up_min", "Đứng thẳng lại — vượt góc này là kết thúc rep",
                155.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("back_straight_min", "Lưng thẳng — thân phải mở ít nhất góc này",
                150.0, 80.0, 180.0),
        Tunable("knee_overshoot", "Gối vượt mũi chân — tỉ lệ theo chiều rộng khung hình",
                0.05, 0.0, 0.30, unit="", step=0.01),
    ],
    "LungeAnalyzer": [
        Tunable("knee_depth", "Độ sâu gối trước — gập dưới góc này mới tính đủ sâu",
                100.0, 40.0, 140.0, affects_rep_count=True),
        Tunable("stand_up_min", "Đứng thẳng lại — vượt góc này là kết thúc rep",
                160.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("back_straight_min", "Thân thẳng — vai-hông-gối phải mở ít nhất góc này",
                150.0, 80.0, 180.0),
        Tunable("knee_overshoot", "Gối vượt mũi chân — tỉ lệ theo chiều rộng khung hình",
                0.05, 0.0, 0.30, unit="", step=0.01),
    ],
    "RowAnalyzer": [
        Tunable("elbow_contracted", "Kéo hết — khuỷu gập dưới góc này mới tính một rep",
                70.0, 30.0, 120.0, affects_rep_count=True),
        Tunable("elbow_extended", "Duỗi hết — vượt góc này là đã thả tạ về",
                150.0, 100.0, 180.0, affects_rep_count=True),
        Tunable("back_straight_min", "Lưng thẳng — vai-hông-gối phải mở ít nhất góc này",
                100.0, 60.0, 180.0),
    ],
    "BenchPressAnalyzer": [
        Tunable("elbow_down", "Hạ tạ — khuỷu gập dưới góc này mới tính đã hạ đủ",
                95.0, 40.0, 130.0, affects_rep_count=True),
        Tunable("elbow_lockout", "Đẩy thẳng — vượt góc này là đã duỗi hết tay",
                160.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("elbow_asymmetry", "Lệch hai tay — chênh quá góc này là đẩy lệch bên",
                25.0, 5.0, 60.0),
    ],
    "OverheadPressAnalyzer": [
        Tunable("elbow_down", "Vị trí bắt đầu — khuỷu gập dưới góc này là tạ đã về ngang vai",
                90.0, 40.0, 130.0, affects_rep_count=True),
        Tunable("elbow_lockout", "Đẩy thẳng qua đầu — vượt góc này là đã duỗi hết tay",
                160.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("elbow_asymmetry", "Lệch hai tay — chênh quá góc này là đẩy lệch bên",
                25.0, 5.0, 60.0),
    ],
    "DeadliftAnalyzer": [
        Tunable("hip_down", "Cúi xuống — góc hông dưới mức này mới tính đã cúi đủ",
                110.0, 50.0, 150.0, affects_rep_count=True),
        Tunable("hip_up", "Đứng thẳng — vượt góc này là đã dựng người hoàn toàn",
                165.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("knee_overshoot", "Gối vượt mũi chân — tỉ lệ theo chiều rộng khung hình",
                0.05, 0.0, 0.30, unit="", step=0.01),
    ],
    "HipThrustAnalyzer": [
        Tunable("hip_down", "Hạ hông — góc hông dưới mức này mới tính đã hạ đủ",
                110.0, 50.0, 150.0, affects_rep_count=True),
        Tunable("hip_up", "Đẩy hông lên — vượt góc này là đã đẩy hết biên độ",
                165.0, 120.0, 180.0, affects_rep_count=True),
        Tunable("hip_asymmetry", "Lệch hai hông — chênh quá góc này là đẩy lệch bên",
                15.0, 5.0, 60.0),
    ],
    "PlankAnalyzer": [
        Tunable("hip_sag", "Võng hông — dưới góc này là hông đã tụt xuống",
                150.0, 100.0, 180.0),
        Tunable("straight_body_min", "Thân thẳng — vai-hông-gối phải mở ít nhất góc này",
                160.0, 100.0, 180.0),
    ],
    "CatCowAnalyzer": [
        Tunable("cat", "Tư thế mèo — cong lưng dưới góc này mới tính đạt",
                140.0, 90.0, 175.0, affects_rep_count=True),
        Tunable("cow", "Tư thế bò — võng lưng vượt góc này mới tính đạt",
                165.0, 120.0, 180.0, affects_rep_count=True),
    ],
    "CurlAnalyzer": [
        Tunable("elbow_contracted", "Curl hết — khuỷu gập dưới góc này mới tính một rep",
                50.0, 20.0, 100.0, affects_rep_count=True),
        Tunable("elbow_extended", "Hạ tạ hết — vượt góc này là đã duỗi tay về vị trí bắt đầu",
                160.0, 110.0, 180.0, affects_rep_count=True),
        Tunable("elbow_asymmetry", "Lệch hai tay — chênh quá góc này là curl lệch bên",
                25.0, 5.0, 60.0),
    ],
    "LateralRaiseAnalyzer": [
        Tunable("shoulder_rest", "Vị trí nghỉ — góc vai dưới mức này là tay đang xuôi theo thân",
                25.0, 5.0, 60.0, affects_rep_count=True),
        Tunable("shoulder_raised", "Đã nâng đủ cao — vượt góc này là tay đã lên ít nhất ngang vai",
                80.0, 50.0, 120.0, affects_rep_count=True),
        Tunable("shoulder_asymmetry", "Lệch hai tay — chênh quá góc này là nâng lệch bên",
                25.0, 5.0, 60.0),
    ],
    "ChestFlyAnalyzer": [
        Tunable("shoulder_contracted", "Khép hết — khuỷu dưới góc này mới tính một rep",
                35.0, 10.0, 80.0, affects_rep_count=True),
        Tunable("shoulder_extended", "Mở hết — vượt góc này là tay đã mở rộng hai bên",
                85.0, 50.0, 130.0, affects_rep_count=True),
        Tunable("shoulder_asymmetry", "Lệch hai tay — chênh quá góc này là khép lệch bên",
                25.0, 5.0, 60.0),
    ],
    "CalfRaiseAnalyzer": [
        Tunable("ankle_rest", "Vị trí nghỉ — góc mắt cá dưới mức này là bàn chân đang áp sàn",
                85.0, 60.0, 110.0, affects_rep_count=True),
        Tunable("ankle_raised", "Đã nhón đủ cao — vượt góc này là đã nhón gót hết cỡ",
                130.0, 100.0, 170.0, affects_rep_count=True),
        Tunable("ankle_asymmetry", "Lệch hai bên — chênh quá góc này là nhón lệch bên",
                20.0, 5.0, 60.0),
    ],
}

# Cặp ngưỡng buộc phải giữ đúng thứ tự (cận dưới, cận trên).
#
# Đây không phải chuyện thẩm mỹ. Hai ngưỡng này là hai đầu của một rep: người
# tập phải đi qua cận dưới rồi quay lại vượt cận trên thì `RepCounter` mới đếm.
# Đảo ngược chúng là đặt ra một điều kiện không bao giờ thoả — bộ đếm đứng im
# ở 0 và không có lỗi nào báo, người dùng chỉ thấy "app không đếm được".
#
# Danh sách để ở cấp module chứ không gắn vào từng analyzer, vì quan hệ này
# thuộc về bản thân cặp khoá — `hip_down` luôn phải nhỏ hơn `hip_up`, bất kể
# analyzer nào đang dùng chúng.
ORDERED_PAIRS: tuple[tuple[str, str], ...] = (
    ("knee_depth", "stand_up_min"),
    ("hip_down", "hip_up"),
    ("elbow_down", "elbow_lockout"),
    ("elbow_contracted", "elbow_extended"),
    ("cat", "cow"),
    ("shoulder_rest", "shoulder_raised"),
    ("shoulder_contracted", "shoulder_extended"),
    ("ankle_rest", "ankle_raised"),
)

# Khoảng cách tối thiểu giữa hai đầu của một rep.
#
# `RepCounter._NEAR_BOTTOM_MARGIN` là 10°: nhánh dự phòng cho FPS thấp coi mọi
# góc trong khoảng `down_threshold + 10` là "đã chạm đáy". Đặt hai ngưỡng gần
# nhau hơn thế thì vùng "đáy" và vùng "đã đứng thẳng" chồng lên nhau, và bộ
# đếm nhảy loạn. Lấy dư ra thành 15° cho chắc.
MIN_REP_RANGE = 15.0


def tunables_for(analyzer_name: str) -> list[Tunable]:
    """Danh sách ngưỡng chỉnh được của một analyzer, rỗng nếu không biết tên."""
    return TUNABLES.get(analyzer_name, [])


def validate(analyzer_name: str, values: dict[str, float]) -> list[str]:
    """Kiểm giá trị admin nhập, trả danh sách lỗi (rỗng = hợp lệ).

    Trả về TẤT CẢ lỗi tìm được chứ không dừng ở lỗi đầu tiên, để admin sửa
    một lượt thay vì bấm Lưu năm lần mới biết hết vấn đề.
    """
    errors: list[str] = []
    allowed = {t.key: t for t in tunables_for(analyzer_name)}

    for key, value in values.items():
        tunable = allowed.get(key)
        if tunable is None:
            errors.append(f"'{key}' không phải ngưỡng của {analyzer_name}.")
            continue
        if not tunable.minimum <= value <= tunable.maximum:
            errors.append(
                f"'{tunable.label}' phải nằm trong khoảng "
                f"{tunable.minimum:g}–{tunable.maximum:g} (đang nhập {value:g})."
            )

    # Kiểm theo TẦNG: có lỗi khoảng thì dừng ở đây, chưa kiểm thứ tự.
    #
    # Vì kiểm thứ tự phải so hai con số với nhau, mà đem một giá trị đã bị từ
    # chối vào so thì ra thông báo vô nghĩa — "ngưỡng đứng thẳng 155° phải lớn
    # hơn ngưỡng chạm đáy 999°" đọc như thể 155 mới là chỗ sai, trong khi vấn
    # đề thật nằm ở 999. Một thông báo sai hướng còn tệ hơn là thiếu thông báo:
    # admin sẽ đi sửa nhầm ô.
    if errors:
        return errors

    # Giá trị nào admin không nhập thì bài tập vẫn chạy bằng mặc định của
    # analyzer, nên phải kiểm thứ tự trên GIÁ TRỊ CÓ HIỆU LỰC — trộn cái nhập
    # với cái mặc định — chứ không chỉ trên phần vừa nhập. Nếu không, hạ mỗi
    # `stand_up_min` xuống dưới mặc định `knee_depth` sẽ lọt qua.
    effective = {t.key: t.default for t in allowed.values()}
    effective.update(values)

    for lower_key, upper_key in ORDERED_PAIRS:
        if lower_key not in allowed or upper_key not in allowed:
            continue
        lower, upper = effective[lower_key], effective[upper_key]
        if upper - lower < MIN_REP_RANGE:
            errors.append(
                f"'{allowed[upper_key].label}' ({upper:g}°) phải lớn hơn "
                f"'{allowed[lower_key].label}' ({lower:g}°) ít nhất {MIN_REP_RANGE:g}° — "
                "gần nhau hơn thế thì bộ đếm rep không hoạt động."
            )

    return errors


# Sai khoá thì ngưỡng vẫn được ghi xuống DB bình thường rồi bị `load_thresholds`
# bỏ qua lúc chạy — không có lỗi nào báo, và triệu chứng là "chỉnh mà không
# thấy đổi gì". Bắt ngay lúc import để hỏng sớm và hỏng rõ.
_unknown = {t.key for group in TUNABLES.values() for t in group} - set(VALUE_COLUMN)
if _unknown:  # pragma: no cover - lỗi lập trình, không phải lỗi dữ liệu
    raise RuntimeError(
        f"TUNABLES chứa khoá không có trong VALUE_COLUMN: {sorted(_unknown)}. "
        "Ngưỡng nhập bằng khoá này sẽ bị bỏ qua trong im lặng lúc chạy."
    )
