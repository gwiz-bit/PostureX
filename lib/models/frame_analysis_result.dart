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
    this.backAngle,
  });

  final double? leftKnee;
  final double? rightKnee;
  final double? leftHip;
  final double? rightHip;
  final double? leftElbow;
  final double? rightElbow;
  final double? backAngle;

  factory KeyAngles.fromJson(Map<String, dynamic> json) => KeyAngles(
        leftKnee: (json['left_knee'] as num?)?.toDouble(),
        rightKnee: (json['right_knee'] as num?)?.toDouble(),
        leftHip: (json['left_hip'] as num?)?.toDouble(),
        rightHip: (json['right_hip'] as num?)?.toDouble(),
        leftElbow: (json['left_elbow'] as num?)?.toDouble(),
        rightElbow: (json['right_elbow'] as num?)?.toDouble(),
        backAngle: (json['back_angle'] as num?)?.toDouble(),
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
  });

  final int repCount;
  final List<String> errors;
  final bool correct;
  final KeyAngles keyAngles;
  final String phase;

  factory FrameAnalysisResult.fromJson(Map<String, dynamic> json) =>
      FrameAnalysisResult(
        repCount: json['rep_count'] as int,
        errors: (json['errors'] as List).cast<String>(),
        correct: json['correct'] as bool,
        keyAngles: KeyAngles.fromJson(json['key_angles'] as Map<String, dynamic>),
        phase: json['phase'] as String,
      );
}
