import '../../../../services/api_client.dart';
import '../../domain/entities/ai_config.dart';

class AIConfigRemoteDataSource {
  const AIConfigRemoteDataSource(this._client);

  final ApiClient _client;

  Future<AIConfig> fetchConfig() => _client.fetchAIConfig();

  Future<AIConfig> updateConfig(AIConfig config) => _client.updateAIConfig(config);
}
