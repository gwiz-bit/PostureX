import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/ai_config.dart';
import '../../domain/repositories/ai_config_repository.dart';
import '../datasources/ai_config_remote_data_source.dart';

class AIConfigRepositoryImpl implements AIConfigRepository {
  const AIConfigRepositoryImpl(this._remote);

  final AIConfigRemoteDataSource _remote;

  @override
  Future<AIConfig> getConfig() => _run(_remote.fetchConfig);

  @override
  Future<AIConfig> updateConfig(AIConfig config) => _run(() => _remote.updateConfig(config));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
