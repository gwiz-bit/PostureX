import '../entities/workout.dart';
import '../repositories/workout_repository.dart';

/// Logs a completed workout session.
class CreateWorkout {
  const CreateWorkout(this._repository);

  final WorkoutRepository _repository;

  Future<Workout> call({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  }) {
    return _repository.createWorkout(
      exercise: exercise,
      totalReps: totalReps,
      durationSeconds: durationSeconds,
      accuracyScore: accuracyScore,
      startedAt: startedAt,
    );
  }
}
