import '../../services/api_client.dart';
import 'data/datasources/admin_plan_remote_data_source.dart';
import 'data/repositories/admin_plan_repository_impl.dart';
import 'domain/repositories/admin_plan_repository.dart';
import 'domain/usecases/create_admin_plan.dart';
import 'domain/usecases/get_admin_plans.dart';
import 'domain/usecases/update_admin_plan.dart';
import 'domain/usecases/validate_plan_form.dart';

class AdminPlansModule {
  AdminPlansModule._();

  static AdminPlanRepository _repository() =>
      AdminPlanRepositoryImpl(AdminPlanRemoteDataSource(ApiClient.instance));

  static GetAdminPlans getAdminPlans() => GetAdminPlans(_repository());

  static CreateAdminPlan createAdminPlan() => CreateAdminPlan(_repository());

  static UpdateAdminPlan updateAdminPlan() => UpdateAdminPlan(_repository());

  static const ValidatePlanForm validatePlanForm = ValidatePlanForm();
}
