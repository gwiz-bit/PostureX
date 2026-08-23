class AdminVideo {
  const AdminVideo({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.originalFilename,
    required this.totalReps,
    required this.accuracyScore,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String exercise;
  final String? originalFilename;
  final int totalReps;
  final double? accuracyScore;
  final DateTime createdAt;

  factory AdminVideo.fromJson(Map<String, dynamic> json) => AdminVideo(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        exercise: json['exercise'] as String,
        originalFilename: json['original_filename'] as String?,
        totalReps: json['total_reps'] as int,
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
