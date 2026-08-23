import '../entities/admin_exercise.dart';
import '../repositories/admin_exercise_repository.dart';

class DeleteAdminExerciseVideo {
  const DeleteAdminExerciseVideo(this._repository);

  final AdminExerciseRepository _repository;

  Future<AdminExercise> call(int exerciseId) => _repository.deleteExerciseVideo(exerciseId);
}
