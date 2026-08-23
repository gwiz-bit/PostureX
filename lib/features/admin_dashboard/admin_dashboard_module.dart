import '../../services/api_client.dart';
import 'data/datasources/admin_dashboard_remote_data_source.dart';
import 'data/repositories/admin_stats_repository_impl.dart';
import 'domain/repositories/admin_stats_repository.dart';
import 'domain/usecases/get_admin_stats.dart';

/// Manual composition root for the Admin Dashboard feature.
class AdminDashboardModule {
  AdminDashboardModule._();

  static AdminStatsRepository _repository() =>
      AdminStatsRepositoryImpl(AdminDashboardRemoteDataSource(ApiClient.instance));

  static GetAdminStats getAdminStats() => GetAdminStats(_repository());
}
