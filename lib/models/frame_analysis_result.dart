/// Per-frame pose angles returned by the `/api/v1/ws/analyze` WebSocket.
/// All angles are in degrees and `null` when that joint wasn't confidently
/// detected in the frame.
class KeyAngles {
  const KeyAngles({
    this.leftKnee,
    this.rightKnee,
    this.leftHip,
    this.rightHip,
    this.leftElbow,
    this.rightElbow,
    this.leftShoulder,
    this.rightShoulder,
    this.leftAnkle,
    this.rightAnkle,
    this.backAngle,
  });

  final double? leftKnee;
  final double? rightKnee;
  final double? leftHip;
  final double? rightHip;
  final double? leftElbow;
  final double? rightElbow;
  // Backend has always sent these (see `KeyAngles` in `app/schemas/analysis.py`)
  // but this model never parsed them, so LateralRaise/ChestFly/Pullover
  // (shoulder angle) and CalfRaise (ankle angle) sessions silently had no
  // usable debug angle — added 15/09/2026 alongside the debug overlay that
  // needs them (see CHANGELOG: "phải đếm được rep, độ chính xác cao").
  final double? leftShoulder;
  final double? rightShoulder;
  final double? leftAnkle;
  final double? rightAnkle;
  final double? backAngle;

  factory KeyAngles.fromJson(Map<String, dynamic> json) => KeyAngles(
        leftKnee: (json['left_knee'] as num?)?.toDouble(),
        rightKnee: (json['right_knee'] as num?)?.toDouble(),
        leftHip: (json['left_hip'] as num?)?.toDouble(),
        rightHip: (json['right_hip'] as num?)?.toDouble(),
        leftElbow: (json['left_elbow'] as num?)?.toDouble(),
        rightElbow: (json['right_elbow'] as num?)?.toDouble(),
        leftShoulder: (json['left_shoulder'] as num?)?.toDouble(),
        rightShoulder: (json['right_shoulder'] as num?)?.toDouble(),
        leftAnkle: (json['left_ankle'] as num?)?.toDouble(),
        rightAnkle: (json['right_ankle'] as num?)?.toDouble(),
        backAngle: (json['back_angle'] as num?)?.toDouble(),
      );
}

/// Normalized (0-1, relative to the source frame) position of one joint —
/// used to draw the skeleton overlay, as opposed to [KeyAngles]' already
/// computed angle values.
class Point {
  const Point({required this.x, required this.y, required this.visibility});

  final double x;
  final double y;
  final double visibility;

  factory Point.fromJson(Map<String, dynamic> json) => Point(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        visibility: (json['visibility'] as num).toDouble(),
      );
}

/// One per-frame result from the analyze socket. [phase] is one of
/// "going_down" | "bottom" | "going_up" | "top" per the backend's rep
/// counter state machine.
class FrameAnalysisResult {
  const FrameAnalysisResult({
    required this.repCount,
    required this.errors,
    required this.correct,
    required this.keyAngles,
    required this.phase,
    required this.keypoints,
    required this.allKeypoints,
    required this.similarityScore,
  });

  final int repCount;
  final List<String> errors;
  final bool correct;
  final KeyAngles keyAngles;
  final String phase;

  /// Keyed by joint name (e.g. "left_knee") — `null`/absent entries mean
  /// that joint wasn't confidently detected this frame. `null` as a whole
  /// means no person was detected at all. Only the joints THIS exercise's
  /// analyzer actually uses for angle math (squat has no elbows, curl has
  /// no knees) — not a full skeleton. Kept mainly for debugging/analysis;
  /// [allKeypoints] is what the UI should draw.
  final Map<String, Point>? keypoints;

  /// Every MediaPipe landmark the backend bothers to expose (33 minus the
  /// fingertip points — too small/noisy to be worth drawing), independent
  /// of which exercise is being analyzed. This is what [SkeletonPainter]
  /// should use so the overlay tracks the whole body (face, elbows,
  /// wrists...) instead of only the handful of joints the active
  /// exercise's rep-counting math happens to touch.
  final Map<String, Point>? allKeypoints;

  /// "Độ giống bài mẫu" (0-100), so chuỗi góc live với chuẩn trích từ video
  /// mẫu — xem `app/ml/similarity_scorer.py`. `null` khi bài chưa có chuẩn
  /// tham chiếu (đa số bài, mới 113/204) HOẶC cửa sổ live chưa đủ frame để
  /// tính — KHÔNG có nghĩa "tập sai hoàn toàn", UI nên ẩn hẳn thanh điểm khi
  /// `null` thay vì hiện 0%.
  final double? similarityScore;

  factory FrameAnalysisResult.fromJson(Map<String, dynamic> json) =>
      FrameAnalysisResult(
        repCount: json['rep_count'] as int,
        errors: (json['errors'] as List).cast<String>(),
        correct: json['correct'] as bool,
        keyAngles: KeyAngles.fromJson(json['key_angles'] as Map<String, dynamic>),
        phase: json['phase'] as String,
        keypoints: (json['keypoints'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, Point.fromJson(value as Map<String, dynamic>)),
        ),
        allKeypoints: (json['all_keypoints'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, Point.fromJson(value as Map<String, dynamic>)),
        ),
        similarityScore: (json['similarity_score'] as num?)?.toDouble(),
      );
}
