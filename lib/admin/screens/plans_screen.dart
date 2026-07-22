import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../../models/plan.dart';
import '../models/admin_models.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import 'add_plan_screen.dart';
import 'add_promo_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<Plan> _plans = [];
  List<AdminPromoCode> _promos = [];
  bool _isLoading = true;
  String? _errorMessage;

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
        ApiClient.instance.fetchAdminPlans(),
        ApiClient.instance.fetchAdminPromoCodes(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<Plan>;
        _promos = results[1] as List<AdminPromoCode>;
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stopPlan(Plan p) async {
    final ok = await showConfirmDialog(context, 'Stop selling ${p.name}?',
        'Plan will be hidden from app. Existing subscribers keep their history (data retained).');
    if (!ok) return;
    try {
      await ApiClient.instance.updateAdminPlan(p.id, isActive: false);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _resumePlan(Plan p) async {
    try {
      await ApiClient.instance.updateAdminPlan(p.id, isActive: true);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _deletePlan(Plan p) async {
    final ok = await showConfirmDialog(context, 'Delete ${p.name}?',
        'This permanently removes the plan. Past transactions referencing it are kept, but it can no longer be sold.');
    if (!ok) return;
    try {
      await ApiClient.instance.deleteAdminPlan(p.id);
      if (mounted) {
        _load();
        showToast(context, '${p.name} deleted');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _togglePromo(AdminPromoCode m) async {
    try {
      await ApiClient.instance.updateAdminPromoCode(m.id, isActive: !m.isActive);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _deletePromo(AdminPromoCode m) async {
    final ok = await showConfirmDialog(context, 'Delete ${m.code}?', 'This permanently removes the promo code.');
    if (!ok) return;
    try {
      await ApiClient.instance.deleteAdminPromoCode(m.id);
      if (mounted) {
        _load();
        showToast(context, '${m.code} deleted');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  void _openAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: kBlueBg,
                child: Icon(Icons.inventory_2_outlined, color: kBlue)),
            title: const Text('Add new plan',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Name, price, duration, benefits'),
            onTap: () async {
              Navigator.pop(c);
              final created = await Navigator.push<Plan>(context,
                  MaterialPageRoute(builder: (_) => const AddPlanScreen()));
              if (created != null && mounted) {
                _load();
                showToast(context, 'New plan saved');
              }
            },
          ),
          ListTile(
            leading: const CircleAvatar(
                backgroundColor: kAmberBg,
                child: Icon(Icons.local_offer_outlined, color: kAmber)),
            title: const Text('Add promo code',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Code, discount %, expiry'),
            onTap: () async {
              Navigator.pop(c);
              final created = await Navigator.push<AdminPromoCode>(context,
                  MaterialPageRoute(builder: (_) => const AddPromoScreen()));
              if (created != null && mounted) {
                _load();
                showToast(context, 'Promo code created');
              }
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Plan Management',
          '${_plans.length} plans · ${_promos.length} promo codes',
          actions: [
            IconButton(onPressed: _openAddMenu, icon: const Icon(Icons.add))
          ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _errorMessage != null
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: [
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ]),
                    ),
                  ])
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SectionLabel('Plans'),
                      ListCard(
                        rows: _plans.map((p) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              CircleAvatar(
                                  radius: 17,
                                  backgroundColor: kBlueBg,
                                  child: Icon(_iconFor(p.name), size: 17, color: kBlue)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                    Text(p.name,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                    Text(
                                        p.priceVnd == 0
                                            ? '0₫'
                                            : '${p.priceVnd}₫ / ${p.durationMonths == 12 ? 'year' : 'month'}',
                                        style: const TextStyle(fontSize: 11, color: kMuted)),
                                  ])),
                              StatusBadge(p.isActive ? 'Active' : 'Inactive',
                                  p.isActive ? kGreenBg : kGrayBg,
                                  p.isActive ? kGreen : kGrayFg),
                              if (p.isActive && p.priceVnd > 0) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                    onTap: () => _stopPlan(p),
                                    child: const Icon(Icons.block, size: 19, color: kRed)),
                              ],
                              if (!p.isActive) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                    onTap: () => _resumePlan(p),
                                    child: const Icon(Icons.play_circle_outline, size: 19, color: kGreen)),
                              ],
                              const SizedBox(width: 8),
                              InkWell(
                                  onTap: () => _deletePlan(p),
                                  child: const Icon(Icons.delete_outline, size: 19, color: kRed)),
                            ]),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Promo codes'),
                      if (_promos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No promo codes yet', style: TextStyle(color: kMuted))),
                        )
                      else
                        ListCard(
                          rows: _promos.map((m) {
                            final expired = m.expiresAt != null && m.expiresAt!.isBefore(DateTime.now());
                            final valid = m.isActive && !expired;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                      Text(m.code,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                      Text(
                                          '${m.discountPercent}% off'
                                          '${m.expiresAt == null ? '' : ' · Expires ${m.expiresAt!.day.toString().padLeft(2, '0')}/${m.expiresAt!.month.toString().padLeft(2, '0')}'}',
                                          style: const TextStyle(fontSize: 11, color: kMuted)),
                                    ])),
                                StatusBadge(valid ? 'Valid' : 'Expired',
                                    valid ? kGreenBg : kGrayBg, valid ? kGreen : kGrayFg),
                                if (!expired) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                      onTap: () => _togglePromo(m),
                                      child: Icon(
                                          m.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                          size: 19,
                                          color: m.isActive ? kRed : kGreen)),
                                ],
                                const SizedBox(width: 8),
                                InkWell(
                                    onTap: () => _deletePromo(m),
                                    child: const Icon(Icons.delete_outline, size: 19, color: kRed)),
                              ]),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
      ),
    );
  }
}
