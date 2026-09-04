import '../entities/posture_rules.dart';
import '../repositories/posture_rules_repository.dart';

class GetExerciseRules {
  const GetExerciseRules(this._repository);

  final PostureRulesRepository _repository;

  Future<ExerciseRules> call(int exerciseId) => _repository.getRules(exerciseId);
}
