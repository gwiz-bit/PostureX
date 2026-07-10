import '../models/workout.dart';

/// Aggregates computed from a user's workout history — shared by the
/// Progress and Profile screens so the averaging logic isn't duplicated.
class WorkoutStats {
  const WorkoutStats({
    required this.sessionCount,
    required this.totalReps,
    required this.averageAccuracy,
    required this.bestAccuracy,
  });

  final int sessionCount;
  final int totalReps;
  final double? averageAccuracy;
  final double? bestAccuracy;
}

WorkoutStats computeStats(List<Workout> workouts) {
  final scores = [
    for (final w in workouts)
      if (w.accuracyScore != null) w.accuracyScore!,
  ];

  return WorkoutStats(
    sessionCount: workouts.length,
    totalReps: workouts.fold(0, (sum, w) => sum + w.totalReps),
    averageAccuracy:
        scores.isEmpty ? null : scores.reduce((a, b) => a + b) / scores.length,
    bestAccuracy: scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b),
  );
}
