import '../../../../services/api_client.dart';
import '../../domain/entities/workout.dart';

/// Thin wrapper around [ApiClient]'s workout endpoints — the only place in
/// the workout feature allowed to know the REST layer exists.
class WorkoutRemoteDataSource {
  const WorkoutRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Workout>> fetchWorkouts() => _client.fetchWorkouts();

  Future<Workout> createWorkout({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  }) {
    return _client.createWorkout(
      exercise: exercise,
      totalReps: totalReps,
      durationSeconds: durationSeconds,
      accuracyScore: accuracyScore,
      startedAt: startedAt,
    );
  }
}
