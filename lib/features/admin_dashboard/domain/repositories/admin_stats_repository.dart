import '../entities/system_stats.dart';

abstract class AdminStatsRepository {
  Future<SystemStats> getStats();
}
