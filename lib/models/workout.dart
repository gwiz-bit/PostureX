/// Maps the backend's `WorkoutOut` schema.
class Workout {
  const Workout({
    required this.id,
    required this.exercise,
    required this.totalReps,
    required this.durationSeconds,
    required this.accuracyScore,
    required this.startedAt,
    required this.endedAt,
    required this.createdAt,
  });

  final int id;
  final String exercise;
  final int totalReps;
  final double? durationSeconds;
  final double? accuracyScore;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as int,
        exercise: json['exercise'] as String,
        totalReps: json['total_reps'] as int,
        durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
        accuracyScore: (json['accuracy_score'] as num?)?.toDouble(),
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
