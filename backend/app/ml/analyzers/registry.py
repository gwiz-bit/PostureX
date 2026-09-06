"""Ánh xạ tên bài tập -> analyzer class, tách riêng khỏi `routes/realtime.py`.

Tách ra vì hai nơi cần biết danh sách này, mà chỉ một trong hai cần chạy
phân tích thật:

- `routes/realtime.py` — lấy đúng analyzer cho phiên WebSocket.
- `routes/exercises.py` — chỉ cần biết bài nào *có* analyzer, để trả cờ
  `supports_analysis` cho client ẩn nút "Phân tích tư thế" ở những bài không
  hỗ trợ.

Nếu để registry nằm trong `realtime.py` thì route danh sách bài tập phải
import cả module đó — kéo theo `PoseEstimator` được khởi tạo ở cấp module,
tức nạp mediapipe chỉ để đọc vài cái tên. Module này không import mediapipe
(các analyzer chỉ tính góc khớp), nên nhẹ.

`routes/realtime.py` vẫn fallback sang `SquatAnalyzer` cho tên lạ, nhưng đó
là lưới an toàn cuối cùng — client nên dùng `supports_analysis` để không bao
giờ đẩy người dùng vào tình huống đó, vì feedback squat đọc cho một bài tập
cổ là sai hoàn toàn.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.bench_press import BenchPressAnalyzer
from app.ml.analyzers.calf_raise import CalfRaiseAnalyzer
from app.ml.analyzers.cat_cow import CatCowAnalyzer
from app.ml.analyzers.chest_fly import ChestFlyAnalyzer
from app.ml.analyzers.curl import CurlAnalyzer
from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.lateral_raise import LateralRaiseAnalyzer
from app.ml.analyzers.leg_extension import LegExtensionAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.overhead_press import OverheadPressAnalyzer
from app.ml.analyzers.plank import PlankAnalyzer
from app.ml.analyzers.row import RowAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer
from app.ml.analyzers.tricep_extension import TricepExtensionAnalyzer

# ─────────────────────────────────────────────────────────────────────────
# Vì sao phải liệt kê từng biến thể thay vì khớp theo chuỗi con
# ─────────────────────────────────────────────────────────────────────────
# Thư viện dùng tên mô tả đầy đủ ("Barbell Bent Over Row") chứ không phải tên
# họ động tác ("Row"), nên khớp đúng tên chỉ với tới 5/417 bài — tính năng
# phân tích tư thế gần như không dùng được.
#
# Khớp theo chuỗi con thì phủ được nhiều, nhưng sai theo cách nguy hiểm hơn là
# không phủ, vì người tập nhận hướng dẫn sai mà vẫn tưởng đúng:
#
#   - "Barbell Upright Row" chứa "row" nhưng là bài vai kéo dọc thân, cơ chế
#     khác hẳn row cúi người — ngưỡng khuỷu tay của RowAnalyzer chấm sai hoàn toàn.
#   - "Nar-row Pulldown" chứa "row" mà không liên quan gì tới động tác row.
#   - "Rowing Machine Steady State" là cardio máy chèo, không phải bài kéo tạ.
#
# Nên mỗi tên dưới đây đã được đối chiếu với đúng thứ analyzer đó thật sự đo.
#
# Ba quy tắc loại trừ được áp dụng, đều xuất phát từ code của analyzer chứ
# không phải cảm tính:
#
# 1. LOẠI biến thể MỘT BÊN khi analyzer gộp/so hai bên:
#    - `RowAnalyzer` lấy `avg()` góc hai khuỷu tay. Row một tay thì tay rảnh
#      giữ nguyên ~170°, trung bình không bao giờ xuống tới ngưỡng 70° — rep
#      không đếm được và app báo "kéo tạ chưa hết" suốt buổi.
#    - `HipThrustAnalyzer` báo lỗi khi hai hông lệch quá 15°,
#      `BenchPressAnalyzer`/`OverheadPressAnalyzer` khi hai tay lệch quá 25°.
#      Bài một bên vi phạm ngưỡng đó ở mọi rep — toàn cảnh báo giả.
#
# 2. Squat kiểu ĐỨNG SO LE (split/Bulgarian) map sang `LungeAnalyzer`, KHÔNG
#    phải `SquatAnalyzer`: squat lấy trung bình hai gối, còn lunge lấy `min()`
#    — đúng với tư thế một chân trước một chân sau (xem docstring lunge.py).
#
# 3. LOẠI bài khác mặt phẳng chuyển động: lateral/cossack/curtsy (sang ngang),
#    side plank (nằm nghiêng), upright row (kéo dọc). Ngưỡng góc dựng cho mặt
#    phẳng trước-sau không áp được.
#
# Khi thêm bài mới, đọc analyzer trước rồi mới thêm tên — thà thiếu còn hơn
# chấm sai.

_SQUAT_VARIANTS = [
    # Squat hai chân, thân tương đối thẳng, gối là khớp chính.
    "squat",
    "barbell squat",
    "barbell banded back squat",
    "bodyweight squat",
    "bodyweight box squat",
    "front squat",
    "dumbbell front squat",
    "dumbbell front squat tempo",
    "dumbbell goblet squat",
    "kettlebell goblet squat",
    "dumbbell sumo squat",
    "dumbbell overhead squat",
    "band squat",
    "belt squat",
    "zercher squat",
    "pause squat",
    "smith machine squat",
    "smith machine front squat",
    "machine hack squat",
    "reverse hack squat",
    "pendulum squat v squat",
    # KHÔNG có: Jump Squats (có pha bay, ngưỡng gối-vượt-mũi-chân sai lúc
    # tiếp đất), Sissy Squat (cố ý đẩy gối vượt xa mũi chân — cảnh báo giả
    # mọi rep), Cossack Squat (squat sang ngang).
]

_LUNGE_VARIANTS = [
    # Đứng so le: một chân trước, một chân sau. LungeAnalyzer dùng min() hai
    # gối nên đọc đúng chân trước.
    "lunge",
    "forward lunge",
    "lunge walking",
    "dumbbell alternating forward lunge",
    "dumbbell goblet forward lunge",
    "plate forward lunge",
    "barbell reverse lunge",
    "bodyweight reverse lunge",
    "bodyweight alternating reverse lunges",
    "dumbbell goblet reverse lunge",
    # Split squat cũng là tư thế so le — xem quy tắc 2 ở trên.
    "barbell split squat",
    "bulgarian split squat",
    "dumbbell bulgarian split squat",
    "dumbbell goblet bulgarian split squat",
    "dumbbell goblet split squat",
    "kettlebell assisted bulgarian split squat",
    "front foot elevated split squat",
    # KHÔNG có: lateral lunge và curtsy lunge (bước sang ngang / chéo ra sau),
    # Split Squat Isometric Hold (giữ tĩnh, không có rep để đếm).
]

_DEADLIFT_VARIANTS = [
    # Gập-duỗi hông hai chân (hip hinge).
    "deadlift",
    "barbell deadlift",
    "dumbbell deadlift",
    "bodyweight deadlift",
    "trap bar deadlift",
    "snatch grip deadlift",
    "deficit deadlift",
    "kettlebell sumo deadlift",
    "barbell romanian deadlift",
    "band romanian deadlift",
    "kettlebell romanian deadlift",
    "deficit dumbbell romanian deadlift",
    "barbell stiff leg deadlifts",
    "smith machine sumo romanian deadlift",
    "hip hinge speed romanian deadlift",
    "good mornings",  # gập-duỗi hông có tải trên vai, cùng trục góc với RDL.
    # KHÔNG có: mọi biến thể một chân (Single Leg / Single Legged / Kickstand)
    # — thân và chân sau tạo thành đường thẳng, góc hông đọc ra khác hẳn; và
    # Dumbbell Cross Body RDL (có xoay thân).
    # KHÔNG có (chưa đủ tự tin, để rà lại sau): Barbell Rack Pull (ROM một
    # phần — bắt đầu đã nửa đứng thẳng, không bao giờ chạm đủ sâu theo ngưỡng
    # mặc định của deadlift toàn biên độ), Reverse Hyperextension (nằm sấp
    # trên máy, chân đưa lên — hình học khác hẳn kiểu đứng cúi người),
    # Romanian Deadlift Hamstring Sweeps (nghi là bài giãn cơ/nhịp độ, không
    # rõ có phải bài đếm rep chuẩn không).
]

_ROW_VARIANTS = [
    # Kéo ngang về thân bằng cả hai tay.
    "row",
    "band row",
    "barbell bent over row",
    "barbell bent over row overhand",
    "underhand barbell row",
    "pendlay row",
    "yates row",
    "smith machine bent over row",
    "dumbbell row bilateral",
    "kettlebell row",
    "chest supported dumbbell row",
    "chest supported t bar row",
    "landmine t bar rows",
    "machine plate loaded t bar row",
    "machine neutral row",
    "machine seated cable row",
    "machine underhand row",
    "wide grip seated cable row",
    "cable row bar standing row",
    "cable supinating row",
    "seal row",
    "inverted row",
    "hammer strength high row",
    # KHÔNG có: mọi biến thể một tay (quy tắc 1), Upright Row (kéo dọc, bài
    # vai), Kettlebell Gorilla Row và Hammer Strength Iso Lateral Row (luân
    # phiên từng bên), và ba bài cardio máy chèo (Rowing Intervals / Machine
    # Steady State / Sprint).
]

_BENCH_PRESS_VARIANTS = [
    # Đẩy bằng hai tay. Analyzer chỉ cần thấy rõ vai-khuỷu-cổ tay nên góc ghế
    # phẳng/dốc/ngửa đều đọc được (xem docstring bench_press.py).
    "bench press",
    "barbell bench press",
    "barbell close grip bench press",
    "barbell incline bench press",
    "barbell high incline bench press",
    "wide grip barbell bench press",
    "reverse grip barbell bench press",
    "decline barbell bench press",
    "dumbbell bench press",
    "dumbbell incline bench press",
    "dumbbell decline bench press",
    "neutral grip dumbbell bench press",
    "kettlebell bench press",
    "kettlebell incline bench press",
    "cable bench press",
    "cable incline bench press",
    "cable decline bench press",
    "smith machine bench press",
    "smith machine close grip bench press",
    "smith machine incline bench press",
    "barbell floor press",
    "floor press",
    "cable chest press",
    "decline machine chest press",
    "incline machine chest press",
    "machine chest press",
    "jm press",  # biến thể lai giữa close-grip bench press và skullcrusher,
                 # nhưng vẫn là gập-duỗi khuỷu tay hai bên trên ghế.
    # Push-up: cùng cơ chế góc khuỷu tay (vai-khuỷu-cổ tay) với bench press —
    # xem docstring bench_press.py "không phụ thuộc tư thế nằm hay đứng", nên
    # nằm sấp chống đẩy dưới sàn đọc đúng y hệt nằm ngửa đẩy tạ trên ghế.
    "push up",
    "push-up",
    "incline push up",
    "decline push up",
    "diamond push ups",
    "bodyweight elevated push up",
    "bodyweight knee push ups",
    # Dip: cùng lý do — khuỷu tay gập ở đáy, duỗi thẳng ở đỉnh, chỉ khác
    # hướng thân (tay ra sau thay vì ra trước) mà công thức góc không quan
    # tâm hướng.
    "bench dips",
    "machine dips",
    "parralel bar dips",
    # KHÔNG có (một tay): Dumbbell Single Arm Chest Press, Cable Standing
    # Single Arm Chest Press.
]

_OVERHEAD_PRESS_VARIANTS = [
    # Đẩy qua đầu bằng hai tay.
    "overhead press",
    "barbell overhead press",
    "band overhead press",
    "cable overhead press",
    "dumbbell seated overhead press",
    "kettlebell seated overhead press",
    "smith machine seated overhead press",
    # KHÔNG có: Single Arm Dumbbell Overhead Press (quy tắc 1).
]

_HIP_THRUST_VARIANTS = [
    # Đẩy hông bằng hai chân.
    "hip thrust",
    "barbell hip thrust",
    "kettlebell hip thrust",
    "machine hip thrust",
    "dumbbell heels elevated hip thrust",
    # Glute bridge: cùng cơ chế góc hông với hip thrust — về bản chất là hip
    # thrust không kê vai lên ghế, chỉ khác biên độ.
    "glute bridge",
    "band glute bridge",
    "dumbbell feet elevated glute bridge",
    "frog pump",  # glute bridge hai bàn chân chụm, gối mở rộng — vẫn cùng
                  # trục góc hông.
    # KHÔNG có: Single Leg / B Stance / Figure Four / Single Leg Glute
    # Bridge — ngưỡng lệch hai hông 15° sẽ báo lỗi ở mọi rep (quy tắc 1).
]

_PLANK_VARIANTS = [
    # Giữ tĩnh, thân nằm ngang khung hình.
    "plank",
    "front plank",
    "hand plank",
    # KHÔNG có: Elbow Side Plank — nằm nghiêng, logic võng hông dựng cho tư
    # thế úp không áp được.
]

_CAT_COW_VARIANTS = [
    # Thư viện hiện KHÔNG có bài nào thuộc họ này; giữ lại để client cũ từng
    # gửi tên này vẫn chạy đúng.
    "cat-cow",
]

_CURL_VARIANTS = [
    # Gập khuỷu tay hai bên đồng thời (bar/rope/hai tạ cùng lúc) — CurlAnalyzer
    # lấy avg() hai khuỷu tay giống RowAnalyzer, nên áp dụng đúng quy tắc 1.
    "curl",
    "bicep curl",
    "band curl",
    "barbell curl",
    "barbell drag curl",
    "close grip barbell curl",
    "reverse grip barbell curl",
    "wide grip barbell curl",
    "cable bar curl",
    "cable rope hammer curl",
    "dumbbell curl",
    "dumbbell hammer curl",
    "dumbbell incline curl",
    "dumbbell incline hammer curl",
    "seated dumbbell curl",
    "ez bar preacher curl",
    "ez bar reverse preacher curl",
    "kettlebell curl",
    "kettlebell goblet curl",  # một tạ, hai tay cùng nắm — đối xứng như goblet squat
    "spider curl",
    "zottman curl",
    # KHÔNG có (khớp SAI hoàn toàn dù tên có chữ "curl"):
    #   - *Leg Curl* (Band/Dumbbell/Cable Single Leg Laying/Lying/Seated/
    #     Stability Ball/Towel Slide) + Hamstring Curl + Nordic Hamstring
    #     Curl — gập GỐI (hamstring), không phải khuỷu tay. Cần analyzer
    #     khác hẳn (gối), không phải CurlAnalyzer.
    #   - *Wrist Curl* (Barbell/Cable/Dumbbell) — gập CỔ TAY, khớp khác.
    #   - *Spinal Jefferson Curl* (Barbell/Bodyweight/Dumbbell/Kettlebell) —
    #     cúi gập CỘT SỐNG có tải, không liên quan khuỷu tay dù tên trùng.
    #   - Neck Curl — gập CỔ, khớp khác.
    # KHÔNG có (một tay / lệch bên — quy tắc 1):
    #   - Dumbbell Standing Single Arm (Hammer) Curl — tên đã ghi rõ một tay.
    #   - Dumbbell Concentration Curl — luôn tập một tay theo định nghĩa
    #     (khuỷu tựa đùi trong).
    #   - Cross Body Hammer Curl — luân phiên chéo thân, không đồng thời.
    #   - Bayesian Curl — cable sau lưng, gần như luôn tập một tay.
    #   - Dumbbell Preacher Curl, Machine Preacher Curl — ghế preacher dạng
    #     tạ đơn/máy thường tập một tay một lượt, khác Ez Bar Preacher Curl
    #     (thanh đòn nên bắt buộc hai tay đồng thời).
]

_LATERAL_RAISE_VARIANTS = [
    # Nâng tay dạng vai hai bên đồng thời — LateralRaiseAnalyzer lấy avg()
    # góc hông-vai-khuỷu tay, cùng rủi ro một tay như curl/row (quy tắc 1).
    "band lateral raise",
    "cable front raise",
    "dumbbell front raise",
    "dumbbell incline front raise",
    "dumbbell lateral raise",
    "dumbbell laying reverse fly",   # Rear Delt Fly: cùng chiều lateral raise
    "dumbbell rear delt fly",        # (khép->mở), KHÔNG cùng chiều chest fly.
    "dumbbell seated rear delt fly",
    "kettlebell front raise",
    "machine lateral raise",
    "plate front raise",
    "reverse pec deck",  # máy ép ngực dùng ngược — thực chất là rear delt
                          # fly trên máy, không phải bài ngực dù tên có "pec".
    # KHÔNG có (một tay — quy tắc 1): Band Single Arm Lateral Raise, Cable
    # Low Single Arm Lateral Raise, Leaning Cable Lateral Raise (đứng
    # nghiêng người, luôn tập một tay để đủ biên độ), Single Arm Cable Fly.
]

_CHEST_FLY_VARIANTS = [
    # Khép tay hai bên đồng thời trước ngực — chiều rep NGƯỢC lateral raise
    # (xem docstring chest_fly.py), không được gộp chung danh sách trên.
    "cable bench chest fly",
    "cable high to low fly",
    "cable low to high fly",
    "cable pec fly",
    "dumbbell chest fly",
    "dumbbell decline chest fly",
    "dumbbell incline chest fly",
    "machine pec fly",
]

_CALF_RAISE_VARIANTS = [
    # Nhón gót hai bên đồng thời — CalfRaiseAnalyzer lấy avg() hai mắt cá,
    # cùng rủi ro một chân như curl/row (quy tắc 1).
    "bodyweight donkey calf raise",  # cúi gập hông, nhưng góc mắt cá là khớp
                                       # cục bộ nên không phụ thuộc góc hông.
    "kettlebell calf raise",
    "seated calf raise",              # ngồi, chỉ mắt cá di chuyển — vẫn đọc
                                       # đúng vì góc mắt cá không phụ thuộc
                                       # tư thế ngồi/đứng (cùng lý do bench
                                       # press không phụ thuộc nằm/đứng).
    "smith machine calf raise",
    "standing calf raise machine",
    # KHÔNG có (một chân — quy tắc 1): Dumbbell Single Leg Calf Raise, Single
    # Leg Standing Calf Raise.
    # KHÔNG có (khác chiều động tác dù tên gần giống): Tibialis Raise — đây
    # là GẬP MU BÀN CHÂN (dorsiflexion, kéo mũi chân lên), ngược hẳn calf
    # raise (gập LÒNG bàn chân, đẩy gót lên) — dùng chung analyzer sẽ chấm
    # sai chiều hoàn toàn.
    # KHÔNG có (thiếu tự tin về góc camera trên máy chuyên dụng, để rà kỹ ở
    # giai đoạn sau): Horizontal Leg Press Calf Press.
]

_LEG_EXTENSION_VARIANTS = [
    # Duỗi gối ngồi máy, hai chân đồng thời — LegExtensionAnalyzer lấy avg()
    # hai gối, cùng rủi ro một chân như mọi analyzer khác (quy tắc 1). Chưa
    # thấy biến thể "Single Leg Extension" nào trong thư viện hiện tại.
    "machine leg extension",
    "machine plate loaded leg extension",
]

_TRICEP_EXTENSION_VARIANTS = [
    # Duỗi khuỷu tay hai bên đồng thời (đẩy xuống/ra sau đầu) —
    # TricepExtensionAnalyzer lấy avg() hai khuỷu tay, cùng rủi ro một tay.
    "cable rope overhead tricep extension",
    "dumbbell seated overhead tricep extension",
    "machine tricep extension",
    "cable bar pushdown",
    "machine cable v bar push downs",
    "reverse grip tricep pushdown",
    "dumbbell skullcrusher",
    "dumbbell decline skullcrusher",
    "tate press",
    # KHÔNG có (một tay — quy tắc 1): Single Arm Overhead Cable Extension,
    # Single Arm Tricep Extension.
]

_VARIANTS_BY_ANALYZER: list[tuple[type[ExerciseAnalyzer], list[str]]] = [
    (SquatAnalyzer, _SQUAT_VARIANTS),
    (LungeAnalyzer, _LUNGE_VARIANTS),
    (DeadliftAnalyzer, _DEADLIFT_VARIANTS),
    (RowAnalyzer, _ROW_VARIANTS),
    (BenchPressAnalyzer, _BENCH_PRESS_VARIANTS),
    (OverheadPressAnalyzer, _OVERHEAD_PRESS_VARIANTS),
    (HipThrustAnalyzer, _HIP_THRUST_VARIANTS),
    (PlankAnalyzer, _PLANK_VARIANTS),
    (CatCowAnalyzer, _CAT_COW_VARIANTS),
    (CurlAnalyzer, _CURL_VARIANTS),
    (LateralRaiseAnalyzer, _LATERAL_RAISE_VARIANTS),
    (ChestFlyAnalyzer, _CHEST_FLY_VARIANTS),
    (CalfRaiseAnalyzer, _CALF_RAISE_VARIANTS),
    (LegExtensionAnalyzer, _LEG_EXTENSION_VARIANTS),
    (TricepExtensionAnalyzer, _TRICEP_EXTENSION_VARIANTS),
]

# Key luôn viết thường — `_get_analyzer` và `supports_analysis` đều hạ chữ
# trước khi tra, vì tên trong DB viết hoa đầu từ ("Barbell Bench Press").
ANALYZER_REGISTRY: dict[str, type[ExerciseAnalyzer]] = {
    name: analyzer for analyzer, names in _VARIANTS_BY_ANALYZER for name in names
}

# Một tên chỉ được thuộc về một analyzer. Nếu vô tình chép trùng tên sang hai
# danh sách, dict comprehension ở trên sẽ im lặng lấy cái sau và bài đó bị
# chấm bằng analyzer sai — kiểm ngay lúc import thay vì để lọt ra runtime.
_total_names = sum(len(names) for _, names in _VARIANTS_BY_ANALYZER)
if len(ANALYZER_REGISTRY) != _total_names:
    _seen: set[str] = set()
    _duplicates = sorted(
        {n for _, names in _VARIANTS_BY_ANALYZER for n in names if n in _seen or _seen.add(n)}
    )
    raise AssertionError(f"Tên bài tập bị lặp giữa các analyzer: {_duplicates}")


def supports_analysis(exercise_name: str) -> bool:
    """Bài tập này có analyzer riêng hay không.

    So khớp không phân biệt hoa/thường, giống `_get_analyzer` — tên trong DB
    viết hoa đầu từ ("Bench Press") còn key ở đây viết thường.
    """
    return exercise_name.lower() in ANALYZER_REGISTRY
