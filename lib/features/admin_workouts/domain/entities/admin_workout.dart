class AdminWorkout {
  const AdminWorkout({
    required this.id,
    required this.userId,
    required this.exercise,
    required this.totalReps,
    required this.accuracyScore,
    required this.durationSeconds,
    required this.startedAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String exercise;
  final int totalReps;
  final double? accuracyScore;
  final double? durationSeconds;
  final DateTime startedAt;
  final DateTime createdAt;

  factory AdminWorkout.fromJson(Map<String, dynamic> json) => AdminWorkout(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        exercise: json['exercise'] as String,
        totalReps: json['total_reps'] as int,
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
        startedAt: DateTime.parse(json['started_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
