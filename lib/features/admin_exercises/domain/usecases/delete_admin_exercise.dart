import '../repositories/admin_exercise_repository.dart';

class DeleteAdminExercise {
  const DeleteAdminExercise(this._repository);

  final AdminExerciseRepository _repository;

  Future<void> call(int exerciseId) => _repository.deleteExercise(exerciseId);
}
