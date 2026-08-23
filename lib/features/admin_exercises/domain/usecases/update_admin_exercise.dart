import '../entities/admin_exercise.dart';
import '../repositories/admin_exercise_repository.dart';

class UpdateAdminExercise {
  const UpdateAdminExercise(this._repository);

  final AdminExerciseRepository _repository;

  Future<AdminExercise> call(int exerciseId, {bool? isActive}) {
    return _repository.updateExercise(exerciseId, isActive: isActive);
  }
}
