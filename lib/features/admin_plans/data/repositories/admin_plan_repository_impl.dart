import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/admin_plan.dart';
import '../../domain/repositories/admin_plan_repository.dart';
import '../datasources/admin_plan_remote_data_source.dart';

class AdminPlanRepositoryImpl implements AdminPlanRepository {
  const AdminPlanRepositoryImpl(this._remote);

  final AdminPlanRemoteDataSource _remote;

  @override
  Future<List<AdminPlan>> getPlans() => _run(_remote.fetchPlans);

  @override
  Future<AdminPlan> createPlan({
    required String name,
    required double priceMonthly,
    String currency = 'VND',
    String? features,
  }) {
    return _run(() => _remote.createPlan(
          name: name,
          priceMonthly: priceMonthly,
          currency: currency,
          features: features,
        ));
  }

  @override
  Future<AdminPlan> updatePlan(
    int planId, {
    String? name,
    double? priceMonthly,
    String? currency,
    String? features,
    bool? isActive,
  }) {
    return _run(() => _remote.updatePlan(
          planId,
          name: name,
          priceMonthly: priceMonthly,
          currency: currency,
          features: features,
          isActive: isActive,
        ));
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
