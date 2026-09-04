import '../entities/posture_rules.dart';
import '../repositories/posture_rules_repository.dart';

class ListTunableExercises {
  const ListTunableExercises(this._repository);

  final PostureRulesRepository _repository;

  Future<List<TunableExercise>> call({String? search}) =>
      _repository.listExercises(search: search);
}
