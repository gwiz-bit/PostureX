import '../entities/admin_exercise.dart';
import '../repositories/admin_exercise_repository.dart';

class CreateAdminExercise {
  const CreateAdminExercise(this._repository);

  final AdminExerciseRepository _repository;

  Future<AdminExercise> call({
    required String name,
    String? description,
    String? category,
    String? difficulty,
    String exerciseType = 'Standard',
  }) {
    return _repository.createExercise(
      name: name,
      description: description,
      category: category,
      difficulty: difficulty,
      exerciseType: exerciseType,
    );
  }
}
