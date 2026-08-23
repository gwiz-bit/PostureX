import '../entities/admin_plan.dart';
import '../repositories/admin_plan_repository.dart';

class CreateAdminPlan {
  const CreateAdminPlan(this._repository);

  final AdminPlanRepository _repository;

  Future<AdminPlan> call({
    required String name,
    required double priceMonthly,
    String currency = 'VND',
    String? features,
  }) {
    return _repository.createPlan(
      name: name,
      priceMonthly: priceMonthly,
      currency: currency,
      features: features,
    );
  }
}
