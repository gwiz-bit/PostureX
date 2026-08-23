import '../entities/revenue_stats.dart';

abstract class AdminRevenueRepository {
  Future<RevenueStats> getRevenue();
}
