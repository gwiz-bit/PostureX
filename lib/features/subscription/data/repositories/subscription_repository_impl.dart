import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/checkout.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/user_subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  const SubscriptionRepositoryImpl(this._remote);

  final SubscriptionRemoteDataSource _remote;

  @override
  Future<List<SubscriptionPlan>> getPlans() => _run(_remote.fetchPlans);

  @override
  Future<UserSubscription?> getMySubscription() => _run(_remote.fetchMySubscription);

  @override
  Future<Checkout> startCheckout(int planId) => _run(() => _remote.checkout(planId));

  @override
  Future<UserSubscription> cancelAutoRenew() => _run(_remote.cancelSubscription);

  @override
  Future<UserSubscription> resumeAutoRenew() => _run(_remote.resumeSubscription);

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
