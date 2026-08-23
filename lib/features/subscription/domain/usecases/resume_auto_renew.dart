import '../entities/user_subscription.dart';
import '../repositories/subscription_repository.dart';

class ResumeAutoRenew {
  const ResumeAutoRenew(this._repository);

  final SubscriptionRepository _repository;

  Future<UserSubscription> call() => _repository.resumeAutoRenew();
}
