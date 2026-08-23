import '../entities/admin_plan.dart';
import '../repositories/admin_plan_repository.dart';

class GetAdminPlans {
  const GetAdminPlans(this._repository);

  final AdminPlanRepository _repository;

  Future<List<AdminPlan>> call() => _repository.getPlans();
}
