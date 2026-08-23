import '../entities/user_subscription.dart';
import '../repositories/subscription_repository.dart';

class CancelAutoRenew {
  const CancelAutoRenew(this._repository);

  final SubscriptionRepository _repository;

  Future<UserSubscription> call() => _repository.cancelAutoRenew();
}
