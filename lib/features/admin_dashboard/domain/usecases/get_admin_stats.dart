import '../entities/system_stats.dart';
import '../repositories/admin_stats_repository.dart';

class GetAdminStats {
  const GetAdminStats(this._repository);

  final AdminStatsRepository _repository;

  Future<SystemStats> call() => _repository.getStats();
}
