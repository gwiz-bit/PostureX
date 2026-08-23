import '../../services/api_client.dart';
import 'data/datasources/admin_revenue_remote_data_source.dart';
import 'data/repositories/admin_revenue_repository_impl.dart';
import 'domain/repositories/admin_revenue_repository.dart';
import 'domain/usecases/get_admin_revenue.dart';

class AdminRevenueModule {
  AdminRevenueModule._();

  static AdminRevenueRepository _repository() =>
      AdminRevenueRepositoryImpl(AdminRevenueRemoteDataSource(ApiClient.instance));

  static GetAdminRevenue getAdminRevenue() => GetAdminRevenue(_repository());
}
