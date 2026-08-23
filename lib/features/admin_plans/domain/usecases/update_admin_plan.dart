import '../entities/admin_plan.dart';
import '../repositories/admin_plan_repository.dart';

class UpdateAdminPlan {
  const UpdateAdminPlan(this._repository);

  final AdminPlanRepository _repository;

  Future<AdminPlan> call(
    int planId, {
    String? name,
    double? priceMonthly,
    String? currency,
    String? features,
    bool? isActive,
  }) {
    return _repository.updatePlan(
      planId,
      name: name,
      priceMonthly: priceMonthly,
      currency: currency,
      features: features,
      isActive: isActive,
    );
  }
}
