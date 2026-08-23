import '../repositories/admin_workout_repository.dart';

class DeleteAdminWorkout {
  const DeleteAdminWorkout(this._repository);

  final AdminWorkoutRepository _repository;

  Future<void> call(int workoutId) => _repository.deleteWorkout(workoutId);
}
