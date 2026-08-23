import '../../../../services/api_client.dart';
import '../../domain/entities/checkout.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/user_subscription.dart';

class SubscriptionRemoteDataSource {
  const SubscriptionRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<SubscriptionPlan>> fetchPlans() => _client.fetchPlans();

  Future<UserSubscription?> fetchMySubscription() => _client.fetchMySubscription();

  Future<Checkout> checkout(int planId) => _client.checkout(planId);

  Future<UserSubscription> cancelSubscription() => _client.cancelSubscription();

  Future<UserSubscription> resumeSubscription() => _client.resumeSubscription();
}
