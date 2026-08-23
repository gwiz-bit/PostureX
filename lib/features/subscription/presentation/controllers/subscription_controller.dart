import 'package:flutter/foundation.dart';

import '../../domain/entities/checkout.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/user_subscription.dart';
import '../../domain/usecases/cancel_auto_renew.dart';
import '../../domain/usecases/get_my_subscription.dart';
import '../../domain/usecases/get_plans.dart';
import '../../domain/usecases/resume_auto_renew.dart';
import '../../domain/usecases/start_checkout.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    required GetPlans getPlans,
    required GetMySubscription getMySubscription,
    required StartCheckout startCheckout,
    required CancelAutoRenew cancelAutoRenew,
    required ResumeAutoRenew resumeAutoRenew,
  })  : _getPlans = getPlans,
        _getMySubscription = getMySubscription,
        _startCheckout = startCheckout,
        _cancelAutoRenew = cancelAutoRenew,
        _resumeAutoRenew = resumeAutoRenew;

  final GetPlans _getPlans;
  final GetMySubscription _getMySubscription;
  final StartCheckout _startCheckout;
  final CancelAutoRenew _cancelAutoRenew;
  final ResumeAutoRenew _resumeAutoRenew;

  bool isLoading = true;
  String? errorMessage;
  List<SubscriptionPlan> plans = const [];
  UserSubscription? current;
  int? selectedPlanId;
  bool isCheckingOut = false;
  bool isUpdatingRenewal = false;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      plans = await _getPlans();
      current = await _getMySubscription();
      // Chọn sẵn gói trả phí rẻ nhất — gói Free không mua được.
      selectedPlanId ??= plans.firstWhere((p) => !p.isFree, orElse: () => plans.first).id;
    } catch (_) {
      errorMessage = 'Could not load subscription plans.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectPlan(int planId) {
    selectedPlanId = planId;
    notifyListeners();
  }

  /// Starts checkout for [plan] — throws on failure so the screen can show
  /// its own error message; navigation to the payment WebView stays a
  /// presentation concern, not something this controller does.
  Future<Checkout> startCheckout(SubscriptionPlan plan) async {
    isCheckingOut = true;
    notifyListeners();
    try {
      return await _startCheckout(plan.id);
    } finally {
      isCheckingOut = false;
      notifyListeners();
    }
  }

  Future<void> setAutoRenew(bool value) async {
    isUpdatingRenewal = true;
    notifyListeners();
    try {
      current = value ? await _resumeAutoRenew() : await _cancelAutoRenew();
    } finally {
      isUpdatingRenewal = false;
      notifyListeners();
    }
  }
}
