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

Thư viện bài tập có hơn 400 bài trong khi ở đây chỉ có 9 analyzer: phần lớn
bài tập KHÔNG phân tích được. `routes/realtime.py` vẫn fallback sang
`SquatAnalyzer` cho tên lạ, nhưng đó là lưới an toàn cuối cùng — client nên
dùng `supports_analysis` để không bao giờ đẩy người dùng vào tình huống đó,
vì feedback squat đọc cho một bài tập cổ là sai hoàn toàn.
"""

from app.ml.analyzers.base import ExerciseAnalyzer
from app.ml.analyzers.bench_press import BenchPressAnalyzer
from app.ml.analyzers.cat_cow import CatCowAnalyzer
from app.ml.analyzers.deadlift import DeadliftAnalyzer
from app.ml.analyzers.hip_thrust import HipThrustAnalyzer
from app.ml.analyzers.lunge import LungeAnalyzer
from app.ml.analyzers.overhead_press import OverheadPressAnalyzer
from app.ml.analyzers.plank import PlankAnalyzer
from app.ml.analyzers.row import RowAnalyzer
from app.ml.analyzers.squat import SquatAnalyzer

# Key phải khớp đúng chuỗi `exercise` client gửi lên khi khởi tạo phiên
# (không phân biệt hoa/thường — xem `_get_analyzer` trong routes/realtime.py).
# Bench press và overhead press mỗi bài nhận hai cách viết vì tên trong DB và
# tên client gửi từng lệch nhau.
ANALYZER_REGISTRY: dict[str, type[ExerciseAnalyzer]] = {
    "squat": SquatAnalyzer,
    "row": RowAnalyzer,
    "bench press": BenchPressAnalyzer,
    "dumbbell bench press": BenchPressAnalyzer,
    "plank": PlankAnalyzer,
    "lunge": LungeAnalyzer,
    "deadlift": DeadliftAnalyzer,
    "overhead press": OverheadPressAnalyzer,
    "barbell overhead press": OverheadPressAnalyzer,
    "hip thrust": HipThrustAnalyzer,
    "cat-cow": CatCowAnalyzer,
}


def supports_analysis(exercise_name: str) -> bool:
    """Bài tập này có analyzer riêng hay không.

    So khớp không phân biệt hoa/thường, giống `_get_analyzer` — tên trong DB
    viết hoa đầu từ ("Bench Press") còn key ở đây viết thường.
    """
    return exercise_name.lower() in ANALYZER_REGISTRY
