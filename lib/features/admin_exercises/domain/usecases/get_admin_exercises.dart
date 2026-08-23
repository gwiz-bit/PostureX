import '../entities/admin_exercise.dart';
import '../repositories/admin_exercise_repository.dart';

class GetAdminExercises {
  const GetAdminExercises(this._repository);

  final AdminExerciseRepository _repository;

  Future<List<AdminExercise>> call() => _repository.getExercises();
}
