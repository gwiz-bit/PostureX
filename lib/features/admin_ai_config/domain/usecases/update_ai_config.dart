import '../entities/ai_config.dart';
import '../repositories/ai_config_repository.dart';

class UpdateAIConfig {
  const UpdateAIConfig(this._repository);

  final AIConfigRepository _repository;

  Future<AIConfig> call(AIConfig config) => _repository.updateConfig(config);
}
