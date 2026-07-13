import 'package:flutter/material.dart';

import '../models/plan.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Plan> _plans = [];
  Plan? _currentPlan;
  bool _isLoading = true;
  String? _errorMessage;
  int? _subscribingPlanId;

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
      final results = await Future.wait([
        ApiClient.instance.fetchPlans(),
        ApiClient.instance.fetchMyPlan(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<Plan>;
        _currentPlan = results[1] as Plan?;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _subscribe(Plan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Subscribe to ${plan.name}?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          plan.priceVnd == 0
              ? 'Switch to the Free plan.'
              : 'This will charge ${_formatPrice(plan.priceVnd)}₫ / month (mock payment — no real card is charged).',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _subscribingPlanId = plan.id);
    try {
      await ApiClient.instance.subscribe(planId: plan.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You are now on the ${plan.name} plan.')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reach the server. Check your connection.')),
      );
    } finally {
      if (mounted) setState(() => _subscribingPlanId = null);
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Unlock your full potential',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final plan in _plans) ...[
                  Expanded(child: _buildPlanCard(plan)),
                  if (plan != _plans.last) const SizedBox(width: 14),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No commitment · Cancel anytime',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Plan plan) {
    final isCurrent = _currentPlan?.id == plan.id || (_currentPlan == null && plan.priceVnd == 0);
    return _PlanCard(
      selected: isCurrent,
      onTap: isCurrent ? () {} : () => _subscribe(plan),
      icon: _iconFor(plan.name),
      name: plan.name,
      tagline: plan.tagline ?? '',
      price: plan.priceVnd == 0 ? '0₫' : '${_formatPrice(plan.priceVnd)}₫',
      period: plan.priceVnd == 0 ? '' : '/ month',
      ctaLabel: isCurrent ? 'Current plan' : 'Get ${plan.name}',
      ctaOutline: isCurrent,
      isLoading: _subscribingPlanId == plan.id,
      badge: plan.name == 'Pro' ? 'BEST VALUE' : null,
      features: plan.featureLines.map((f) => _Feature(f)).toList(),
    );
  }

  IconData _iconFor(String planName) {
    switch (planName) {
      case 'Advanced':
        return Icons.star_border_rounded;
      case 'Pro':
        return Icons.workspace_premium_outlined;
      default:
        return Icons.card_giftcard_outlined;
    }
  }

  String _formatPrice(int vnd) {
    final s = vnd.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}

class _Feature {
  const _Feature(this.text);
  final String text;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.name,
    required this.tagline,
    required this.price,
    required this.period,
    required this.ctaLabel,
    required this.features,
    this.badge,
    this.ctaOutline = false,
    this.isLoading = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String name;
  final String tagline;
  final String price;
  final String period;
  final String ctaLabel;
  final List<_Feature> features;
  final String? badge;
  final bool ctaOutline;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 22),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tagline,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        price,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (period.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          period,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ctaOutline
                      ? OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            foregroundColor: AppColors.textSecondary,
                          ),
                          child: Text(
                            ctaLabel,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: isLoading ? null : onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                                )
                              : Text(
                                  ctaLabel,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                        ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Feature list
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f.text,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
