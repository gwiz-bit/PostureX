import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import 'payment_webview_screen.dart';

/// Chọn và mua gói cước.
///
/// Gói + giá đọc từ `GET /subscriptions/plans`, **không hardcode** — bản trước
/// ghi cứng 199k/299k trong khi database bán 99k/199k, và không ai phát hiện ra
/// vì hai bên chẳng bao giờ gặp nhau.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<SubscriptionPlan> _plans = [];
  UserSubscription? _current;
  int? _selectedPlanId;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final plans = await ApiClient.instance.fetchPlans();
      final current = await ApiClient.instance.fetchMySubscription();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _current = current;
        // Chọn sẵn gói trả phí rẻ nhất — gói Free không mua được.
        _selectedPlanId ??= plans.firstWhere(
          (p) => !p.isFree,
          orElse: () => plans.first,
        ).id;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load subscription plans.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startCheckout(SubscriptionPlan plan) async {
    setState(() => _isCheckingOut = true);
    try {
      final checkout = await ApiClient.instance.checkout(plan.id);
      if (!mounted) return;

      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(payUrl: checkout.payUrl),
        ),
      );
      if (!mounted) return;

      // Không tin kết quả WebView trả về: hỏi lại backend — chính nó mới là bên
      // xác minh chữ ký VNPay và kích hoạt gói.
      await _load();
      if (!mounted) return;

      final activated = _current?.planId == plan.id;
      if (activated) {
        _showSnack('Đã kích hoạt gói ${plan.name}.');
      } else if (paid == false) {
        _showSnack('Thanh toán không thành công.');
      }
    } on ApiException catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack('Không kết nối được máy chủ.');
    } finally {
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 30, color: AppColors.textPrimary),
        ),
        title: const Text(
          'Choose your plan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final selected = _plans.where((p) => p.id == _selectedPlanId).firstOrNull;
    final isCurrentPlan = selected != null && _current?.planId == selected.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          Text(
            _current == null
                ? 'Unlock your full potential'
                : 'Đang dùng: ${_current!.planName}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final plan = _plans[index];
                return _PlanCard(
                  plan: plan,
                  selected: plan.id == _selectedPlanId,
                  isCurrent: _current?.planId == plan.id,
                  onTap: () => setState(() => _selectedPlanId = plan.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (selected == null || selected.isFree || isCurrentPlan || _isCheckingOut)
                  ? null
                  : () => _startCheckout(selected),
              child: _isCheckingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                    )
                  : Text(_ctaLabel(selected, isCurrentPlan)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thanh toán qua VNPay. Huỷ bất cứ lúc nào.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(SubscriptionPlan? plan, bool isCurrentPlan) {
    if (plan == null) return 'Choose a plan';
    if (isCurrentPlan) return 'Gói hiện tại';
    if (plan.isFree) return 'Gói miễn phí';
    return 'Nâng cấp ${plan.name} · ${plan.formattedPrice}/tháng';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'ĐANG DÙNG',
                      style: TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  plan.formattedPrice,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!plan.isFree)
                  const Text(
                    ' /tháng',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
              ],
            ),
            if (plan.featureList.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final feature in plan.featureList)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
