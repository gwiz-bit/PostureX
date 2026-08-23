import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/entities/subscription_plan.dart';
import '../../domain/entities/user_subscription.dart';
import '../../subscription_module.dart';
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
  final _controller = SubscriptionModule.controller();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startCheckout(SubscriptionPlan plan) async {
    try {
      final checkout = await _controller.startCheckout(plan);
      if (!mounted) return;

      final returned = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(payUrl: checkout.payUrl),
        ),
      );
      if (!mounted) return;

      // WebView chỉ cho biết "đã quay về", KHÔNG cho biết trả tiền chưa. Hỏi lại
      // backend — chính nó mới là bên hỏi MoMo xem đơn đã thanh toán thật chưa.
      await _controller.load();
      if (!mounted) return;

      if (_controller.current?.planId == plan.id) {
        _showSnack('Đã kích hoạt gói ${plan.name}.');
      } else if (returned == true) {
        // Quay về từ MoMo nhưng gói không bật ⇒ chưa trả tiền hoặc đã huỷ.
        _showSnack('Thanh toán chưa hoàn tất.');
      }
    } on AppFailure catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack('Không kết nối được máy chủ.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmCancel() async {
    final current = _controller.current;
    if (current == null) return;

    final endText = current.endDate == null
        ? 'hết hạn'
        : '${current.endDate!.day}/${current.endDate!.month}/${current.endDate!.year}';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Huỷ tự động gia hạn?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        // Nói rõ là KHÔNG mất quyền ngay — người dùng hay sợ bấm huỷ là mất luôn.
        content: Text(
          'Bạn vẫn dùng gói ${current.planName} bình thường tới $endText. '
          'Sau ngày đó gói sẽ tự hết hạn.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Giữ gói'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Huỷ gia hạn'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _setAutoRenew(false);
  }

  Future<void> _setAutoRenew(bool value) async {
    try {
      await _controller.setAutoRenew(value);
      _showSnack(value ? 'Đã bật lại tự động gia hạn.' : 'Đã huỷ tự động gia hạn.');
    } on AppFailure catch (e) {
      if (mounted) _showSnack(e.message);
    } catch (_) {
      if (mounted) _showSnack('Không kết nối được máy chủ.');
    }
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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_controller.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_controller.errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextButton(onPressed: _controller.load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final plans = _controller.plans;
    final current = _controller.current;
    final selected = plans.where((p) => p.id == _controller.selectedPlanId).firstOrNull;
    final isCurrentPlan = selected != null && current?.planId == selected.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          if (current == null)
            const Text(
              'Unlock your full potential',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            )
          else
            _CurrentPlanBanner(
              subscription: current,
              busy: _controller.isUpdatingRenewal,
              onCancel: _confirmCancel,
              onResume: () => _setAutoRenew(true),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: plans.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _PlanCard(
                  plan: plan,
                  selected: plan.id == _controller.selectedPlanId,
                  isCurrent: current?.planId == plan.id,
                  onTap: () => _controller.selectPlan(plan.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (selected == null ||
                      selected.isFree ||
                      isCurrentPlan ||
                      _controller.isCheckingOut)
                  ? null
                  : () => _startCheckout(selected),
              child: _controller.isCheckingOut
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

/// Thẻ trạng thái gói đang dùng: còn bao nhiêu ngày, có tự gia hạn không, và
/// nút huỷ/bật lại.
///
/// Cố ý nói rõ "vẫn dùng tới ngày X" khi đã huỷ — người dùng hay tưởng bấm huỷ
/// là mất quyền ngay lập tức và không dám bấm.
class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({
    required this.subscription,
    required this.busy,
    required this.onCancel,
    required this.onResume,
  });

  final UserSubscription subscription;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onResume;

  String get _expiryText {
    final end = subscription.endDate;
    if (end == null) return 'Không giới hạn thời gian';

    final date = '${end.day}/${end.month}/${end.year}';
    final days = subscription.daysLeft;
    if (days == null) return 'Hết hạn $date';
    if (days <= 0) return 'Hết hạn hôm nay';
    return 'Còn $days ngày · hết hạn $date';
  }

  @override
  Widget build(BuildContext context) {
    final autoRenew = subscription.autoRenew;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đang dùng ${subscription.planName}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _expiryText,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            autoRenew
                ? 'Tự động gia hạn: đang bật'
                : 'Đã huỷ gia hạn — gói sẽ tự hết hạn, không bị trừ tiền thêm',
            style: TextStyle(
              color: autoRenew ? AppColors.textTertiary : AppColors.primary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : (autoRenew ? onCancel : onResume),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                busy
                    ? 'Đang xử lý…'
                    : (autoRenew ? 'Huỷ tự động gia hạn' : 'Bật lại tự động gia hạn'),
              ),
            ),
          ),
        ],
      ),
    );
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
