import '../entities/exercise.dart';
import '../repositories/exercise_repository.dart';

/// Fetches the public exercise library.
class GetExercises {
  const GetExercises(this._repository);

  final ExerciseRepository _repository;

  Future<List<Exercise>> call() => _repository.getExercises();
}
