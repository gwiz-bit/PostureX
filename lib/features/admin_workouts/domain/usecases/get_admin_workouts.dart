import '../entities/admin_workout.dart';
import '../repositories/admin_workout_repository.dart';

class GetAdminWorkouts {
  const GetAdminWorkouts(this._repository);

  final AdminWorkoutRepository _repository;

  Future<List<AdminWorkout>> call() => _repository.getWorkouts();
}
