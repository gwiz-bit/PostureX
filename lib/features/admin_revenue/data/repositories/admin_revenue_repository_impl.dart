import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/revenue_stats.dart';
import '../../domain/repositories/admin_revenue_repository.dart';
import '../datasources/admin_revenue_remote_data_source.dart';

class AdminRevenueRepositoryImpl implements AdminRevenueRepository {
  const AdminRevenueRepositoryImpl(this._remote);

  final AdminRevenueRemoteDataSource _remote;

  @override
  Future<RevenueStats> getRevenue() async {
    try {
      return await _remote.fetchRevenue();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
