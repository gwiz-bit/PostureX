import '../entities/checkout.dart';
import '../entities/subscription_plan.dart';
import '../entities/user_subscription.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlan>> getPlans();

  Future<UserSubscription?> getMySubscription();

  Future<Checkout> startCheckout(int planId);

  Future<UserSubscription> cancelAutoRenew();

  Future<UserSubscription> resumeAutoRenew();
}
