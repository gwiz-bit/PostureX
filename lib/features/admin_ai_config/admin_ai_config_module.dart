import '../../services/api_client.dart';
import 'data/datasources/posture_rules_remote_data_source.dart';
import 'data/repositories/posture_rules_repository_impl.dart';
import 'domain/repositories/posture_rules_repository.dart';
import 'domain/usecases/get_exercise_rules.dart';
import 'domain/usecases/list_tunable_exercises.dart';
import 'domain/usecases/save_exercise_rules.dart';

class AdminAiConfigModule {
  AdminAiConfigModule._();

  static PostureRulesRepository _repository() =>
      PostureRulesRepositoryImpl(PostureRulesRemoteDataSource(ApiClient.instance));

  static ListTunableExercises listExercises() => ListTunableExercises(_repository());

  static GetExerciseRules getRules() => GetExerciseRules(_repository());

  static SaveExerciseRules saveRules() => SaveExerciseRules(_repository());
}
