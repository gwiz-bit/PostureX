"""Bộ ba khớp đại diện cho TỪNG HỌ analyzer, dùng để tính MỘT góc đại diện
khi so khớp thời gian thực với video mẫu (xem `app/ml/similarity_scorer.py`
và `backend/scripts/extract_reference_poses.py` — cả hai đều đọc từ đây,
tách riêng để không lặp lại cùng một quyết định ở hai chỗ và lệch nhau dần).

Không cần đúng tuyệt đối cho MỌI khớp của một bài — chỉ cần đại diện đúng
trục chuyển động CHÍNH của họ analyzer đó, đủ để một chuỗi góc theo thời
gian phản ánh được nhịp rep (co/duỗi, lên/xuống). Analyzer nào chưa liệt kê
dùng mặc định vai-khuỷu-cổ tay — ĐÚNG cho 7 analyzer kéo/đẩy/curl khuỷu tay
(Row/Curl/BenchPress/OverheadPress/Pulldown/TricepExtension/FacePull, đều
tính góc `calculate_angle_3d(shoulder, elbow, wrist)`), nhưng SAI cho bất kỳ
analyzer nào tính góc ở khớp khác — phải liệt kê tường minh, không được để
rơi vào mặc định.

⚠️ Rà lại 13/09/2026 (sau khi thêm hàng loạt analyzer mới trong ngày): file
này khi viết (11/09/2026) chỉ liệt kê 6/16 analyzer lúc đó, khiến
`LateralRaiseAnalyzer`/`ChestFlyAnalyzer`/`PulloverAnalyzer` — cả ba tính góc
ở VAI (`hip, shoulder, elbow`), không phải khuỷu tay — rơi nhầm vào mặc định
suốt từ đó, và các đợt mở rộng registry trong ngày (Crunch/HipAbduction/
HipAdduction/Kickback/CossackSquat/LegCurl/LegPress/CatCow/Plank) chưa từng
được thêm vào đây. Hậu quả: `SimilarityScorer` (nếu bài đó có chuẩn tham
chiếu) so sánh nhầm góc khuỷu tay — gần như không đổi trong suốt các bài này
— thay vì góc thật sự đại diện chuyển động, cho điểm vô nghĩa. Bổ sung đủ
25/25 analyzer đang có trong `ANALYZER_REGISTRY` bên dưới, xác nhận từng khớp
bằng cách đọc trực tiếp lệnh `calculate_angle_3d`/`calculate_angle` trong mỗi
file analyzer, không suy đoán theo tên bài.
"""

PRIMARY_JOINTS: dict[str, tuple[str, str, str]] = {
    "SquatAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LungeAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "CossackSquatAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LegCurlAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LegPressAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LegExtensionAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "DeadliftAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "HipThrustAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "CrunchAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "HipAbductionAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "HipAdductionAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "KickbackAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "CatCowAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "PlankAnalyzer": ("left_shoulder", "left_hip", "left_ankle"),
    "CalfRaiseAnalyzer": ("left_knee", "left_ankle", "left_foot_index"),
    # Góc ở VAI (đỉnh tại shoulder), KHÔNG phải khuỷu tay — khác mặc định.
    "LateralRaiseAnalyzer": ("left_hip", "left_shoulder", "left_elbow"),
    "ChestFlyAnalyzer": ("left_hip", "left_shoulder", "left_elbow"),
    "PulloverAnalyzer": ("left_hip", "left_shoulder", "left_elbow"),
}
# Đúng cho các analyzer còn lại: RowAnalyzer, CurlAnalyzer, BenchPressAnalyzer,
# OverheadPressAnalyzer, PulldownAnalyzer, TricepExtensionAnalyzer,
# FacePullAnalyzer — tất cả tính `calculate_angle_3d(shoulder, elbow, wrist)`.
DEFAULT_JOINTS: tuple[str, str, str] = ("left_shoulder", "left_elbow", "left_wrist")


def primary_joints_for(analyzer_class_name: str) -> tuple[str, str, str]:
    return PRIMARY_JOINTS.get(analyzer_class_name, DEFAULT_JOINTS)
