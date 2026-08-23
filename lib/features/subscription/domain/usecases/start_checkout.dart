import '../entities/checkout.dart';
import '../repositories/subscription_repository.dart';

class StartCheckout {
  const StartCheckout(this._repository);

  final SubscriptionRepository _repository;

  Future<Checkout> call(int planId) => _repository.startCheckout(planId);
}
