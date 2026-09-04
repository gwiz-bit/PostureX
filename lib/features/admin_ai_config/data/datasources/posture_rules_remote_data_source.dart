import '../../../../services/api_client.dart';
import '../../domain/entities/posture_rules.dart';

class PostureRulesRemoteDataSource {
  const PostureRulesRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<TunableExercise>> listExercises({String? search}) =>
      _client.fetchTunableExercises(search: search);

  Future<ExerciseRules> getRules(int exerciseId) => _client.fetchExerciseRules(exerciseId);

  Future<ExerciseRules> saveRules(int exerciseId, Map<String, double> values) =>
      _client.saveExerciseRules(exerciseId, values);
}
