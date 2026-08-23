import '../../../../services/api_client.dart';
import '../../domain/entities/system_stats.dart';

class AdminDashboardRemoteDataSource {
  const AdminDashboardRemoteDataSource(this._client);

  final ApiClient _client;

  Future<SystemStats> fetchStats() => _client.fetchAdminStats();
}
