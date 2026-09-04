import '../entities/posture_rules.dart';
import '../repositories/posture_rules_repository.dart';

class SaveExerciseRules {
  const SaveExerciseRules(this._repository);

  final PostureRulesRepository _repository;

  Future<ExerciseRules> call(int exerciseId, Map<String, double> values) =>
      _repository.saveRules(exerciseId, values);
}
