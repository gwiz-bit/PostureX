import '../../../../services/api_client.dart';
import '../../domain/entities/revenue_stats.dart';

class AdminRevenueRemoteDataSource {
  const AdminRevenueRemoteDataSource(this._client);

  final ApiClient _client;

  Future<RevenueStats> fetchRevenue() => _client.fetchAdminRevenue();
}
