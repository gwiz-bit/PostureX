"""Bộ ba khớp đại diện cho TỪNG HỌ analyzer, dùng để tính MỘT góc đại diện
khi so khớp thời gian thực với video mẫu (xem `app/ml/similarity_scorer.py`
và `backend/scripts/extract_reference_poses.py` — cả hai đều đọc từ đây,
tách riêng để không lặp lại cùng một quyết định ở hai chỗ và lệch nhau dần).

Không cần đúng tuyệt đối cho MỌI khớp của một bài — chỉ cần đại diện đúng
trục chuyển động CHÍNH của họ analyzer đó, đủ để một chuỗi góc theo thời
gian phản ánh được nhịp rep (co/duỗi, lên/xuống). Analyzer nào chưa liệt kê
dùng mặc định vai-khuỷu-cổ tay (khớp tay là phổ biến nhất trong 16 analyzer
hiện có).
"""

PRIMARY_JOINTS: dict[str, tuple[str, str, str]] = {
    "SquatAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "LungeAnalyzer": ("left_hip", "left_knee", "left_ankle"),
    "DeadliftAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "HipThrustAnalyzer": ("left_shoulder", "left_hip", "left_knee"),
    "CalfRaiseAnalyzer": ("left_knee", "left_ankle", "left_foot_index"),
    "LegExtensionAnalyzer": ("left_hip", "left_knee", "left_ankle"),
}
DEFAULT_JOINTS: tuple[str, str, str] = ("left_shoulder", "left_elbow", "left_wrist")


def primary_joints_for(analyzer_class_name: str) -> tuple[str, str, str]:
    return PRIMARY_JOINTS.get(analyzer_class_name, DEFAULT_JOINTS)
