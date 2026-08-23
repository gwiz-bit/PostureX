class AIConfig {
  const AIConfig({
    required this.squatKneeDepthThreshold,
    required this.squatBackStraightMin,
    required this.squatKneeOvershootRatio,
    required this.squatRepDownThreshold,
    required this.squatRepUpThreshold,
    required this.poseModelComplexity,
    required this.poseMinDetectionConfidence,
  });

  final double squatKneeDepthThreshold;
  final double squatBackStraightMin;
  final double squatKneeOvershootRatio;
  final double squatRepDownThreshold;
  final double squatRepUpThreshold;
  final int poseModelComplexity;
  final double poseMinDetectionConfidence;

  factory AIConfig.fromJson(Map<String, dynamic> json) => AIConfig(
        squatKneeDepthThreshold: (json['squat_knee_depth_threshold'] as num).toDouble(),
        squatBackStraightMin: (json['squat_back_straight_min'] as num).toDouble(),
        squatKneeOvershootRatio: (json['squat_knee_overshoot_ratio'] as num).toDouble(),
        squatRepDownThreshold: (json['squat_rep_down_threshold'] as num).toDouble(),
        squatRepUpThreshold: (json['squat_rep_up_threshold'] as num).toDouble(),
        poseModelComplexity: json['pose_model_complexity'] as int,
        poseMinDetectionConfidence: (json['pose_min_detection_confidence'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'squat_knee_depth_threshold': squatKneeDepthThreshold,
        'squat_back_straight_min': squatBackStraightMin,
        'squat_knee_overshoot_ratio': squatKneeOvershootRatio,
        'squat_rep_down_threshold': squatRepDownThreshold,
        'squat_rep_up_threshold': squatRepUpThreshold,
        'pose_model_complexity': poseModelComplexity,
        'pose_min_detection_confidence': poseMinDetectionConfidence,
      };

  AIConfig copyWith({
    double? squatKneeDepthThreshold,
    double? squatBackStraightMin,
    double? squatKneeOvershootRatio,
    double? squatRepDownThreshold,
    double? squatRepUpThreshold,
    int? poseModelComplexity,
    double? poseMinDetectionConfidence,
  }) =>
      AIConfig(
        squatKneeDepthThreshold: squatKneeDepthThreshold ?? this.squatKneeDepthThreshold,
        squatBackStraightMin: squatBackStraightMin ?? this.squatBackStraightMin,
        squatKneeOvershootRatio: squatKneeOvershootRatio ?? this.squatKneeOvershootRatio,
        squatRepDownThreshold: squatRepDownThreshold ?? this.squatRepDownThreshold,
        squatRepUpThreshold: squatRepUpThreshold ?? this.squatRepUpThreshold,
        poseModelComplexity: poseModelComplexity ?? this.poseModelComplexity,
        poseMinDetectionConfidence: poseMinDetectionConfidence ?? this.poseMinDetectionConfidence,
      );
}
