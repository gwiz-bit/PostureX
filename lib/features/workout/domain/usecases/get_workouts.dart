import '../entities/workout.dart';
import '../repositories/workout_repository.dart';

/// Fetches the current user's full workout history.
class GetWorkouts {
  const GetWorkouts(this._repository);

  final WorkoutRepository _repository;

  Future<List<Workout>> call() => _repository.getWorkouts();
}
