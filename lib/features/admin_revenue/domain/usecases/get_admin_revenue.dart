import '../entities/revenue_stats.dart';
import '../repositories/admin_revenue_repository.dart';

class GetAdminRevenue {
  const GetAdminRevenue(this._repository);

  final AdminRevenueRepository _repository;

  Future<RevenueStats> call() => _repository.getRevenue();
}
