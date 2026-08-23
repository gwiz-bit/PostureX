import '../../services/api_client.dart';
import 'data/datasources/subscription_remote_data_source.dart';
import 'data/repositories/subscription_repository_impl.dart';
import 'domain/repositories/subscription_repository.dart';
import 'domain/usecases/cancel_auto_renew.dart';
import 'domain/usecases/get_my_subscription.dart';
import 'domain/usecases/get_plans.dart';
import 'domain/usecases/resume_auto_renew.dart';
import 'domain/usecases/start_checkout.dart';
import 'presentation/controllers/subscription_controller.dart';

/// Manual composition root for the Subscription feature.
class SubscriptionModule {
  SubscriptionModule._();

  static SubscriptionRepository _repository() =>
      SubscriptionRepositoryImpl(SubscriptionRemoteDataSource(ApiClient.instance));

  static SubscriptionController controller() => SubscriptionController(
        getPlans: GetPlans(_repository()),
        getMySubscription: GetMySubscription(_repository()),
        startCheckout: StartCheckout(_repository()),
        cancelAutoRenew: CancelAutoRenew(_repository()),
        resumeAutoRenew: ResumeAutoRenew(_repository()),
      );
}
