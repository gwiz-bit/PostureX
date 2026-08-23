import '../../../../services/api_client.dart';
import '../../domain/entities/admin_plan.dart';

class AdminPlanRemoteDataSource {
  const AdminPlanRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AdminPlan>> fetchPlans() => _client.fetchAdminPlans();

  Future<AdminPlan> createPlan({
    required String name,
    required double priceMonthly,
    String currency = 'VND',
    String? features,
  }) {
    return _client.createAdminPlan(
      name: name,
      priceMonthly: priceMonthly,
      currency: currency,
      features: features,
    );
  }

  Future<AdminPlan> updatePlan(
    int planId, {
    String? name,
    double? priceMonthly,
    String? currency,
    String? features,
    bool? isActive,
  }) {
    return _client.updateAdminPlan(
      planId,
      name: name,
      priceMonthly: priceMonthly,
      currency: currency,
      features: features,
      isActive: isActive,
    );
  }
}
