import '../entities/workout.dart';

/// Port the data layer implements — use cases and controllers depend only
/// on this interface, never on [ApiClient]/`http` directly.
abstract class WorkoutRepository {
  Future<List<Workout>> getWorkouts();

  Future<Workout> createWorkout({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  });
}
