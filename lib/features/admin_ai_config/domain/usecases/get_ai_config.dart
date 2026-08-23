import '../entities/ai_config.dart';
import '../repositories/ai_config_repository.dart';

class GetAIConfig {
  const GetAIConfig(this._repository);

  final AIConfigRepository _repository;

  Future<AIConfig> call() => _repository.getConfig();
}
