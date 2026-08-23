import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/system_stats.dart';
import '../../domain/repositories/admin_stats_repository.dart';
import '../datasources/admin_dashboard_remote_data_source.dart';

class AdminStatsRepositoryImpl implements AdminStatsRepository {
  const AdminStatsRepositoryImpl(this._remote);

  final AdminDashboardRemoteDataSource _remote;

  @override
  Future<SystemStats> getStats() async {
    try {
      return await _remote.fetchStats();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
