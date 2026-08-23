import '../../services/api_client.dart';
import 'data/datasources/ai_config_remote_data_source.dart';
import 'data/repositories/ai_config_repository_impl.dart';
import 'domain/repositories/ai_config_repository.dart';
import 'domain/usecases/get_ai_config.dart';
import 'domain/usecases/update_ai_config.dart';

class AdminAiConfigModule {
  AdminAiConfigModule._();

  static AIConfigRepository _repository() =>
      AIConfigRepositoryImpl(AIConfigRemoteDataSource(ApiClient.instance));

  static GetAIConfig getAIConfig() => GetAIConfig(_repository());

  static UpdateAIConfig updateAIConfig() => UpdateAIConfig(_repository());
}
