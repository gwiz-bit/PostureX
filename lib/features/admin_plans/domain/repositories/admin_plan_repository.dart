import '../entities/admin_plan.dart';

abstract class AdminPlanRepository {
  Future<List<AdminPlan>> getPlans();

  Future<AdminPlan> createPlan({
    required String name,
    required double priceMonthly,
    String currency = 'VND',
    String? features,
  });

  Future<AdminPlan> updatePlan(
    int planId, {
    String? name,
    double? priceMonthly,
    String? currency,
    String? features,
    bool? isActive,
  });
}
