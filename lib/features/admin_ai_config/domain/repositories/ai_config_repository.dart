import '../entities/ai_config.dart';

abstract class AIConfigRepository {
  Future<AIConfig> getConfig();

  Future<AIConfig> updateConfig(AIConfig config);
}
