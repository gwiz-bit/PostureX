import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<AdminPlan> _plans = [];
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
      final plans = await ApiClient.instance.fetchAdminPlans();
      if (!mounted) return;
      setState(() => _plans = plans);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive(AdminPlan plan) async {
    final targetActive = !plan.isActive;
    final ok = await showConfirmDialog(
      context,
      targetActive ? 'Reactivate ${plan.name}?' : 'Deactivate ${plan.name}?',
      targetActive
          ? '${plan.name} will show up again in the app\'s plan picker.'
          : 'Users who already own this plan keep it until it expires; new purchases are hidden.',
    );
    if (!ok) return;
    try {
      await ApiClient.instance.updateAdminPlan(plan.id, isActive: targetActive);
      if (mounted) _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    }
  }

  Future<void> _openForm({AdminPlan? plan}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PlanFormSheet(plan: plan),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Subscription Plans', '${_plans.length} plans',
          actions: [IconButton(onPressed: () => _openForm(), icon: const Icon(Icons.add))]),
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
                      ListCard(
                        rows: _plans.map((plan) {
                          final (bg, fg) = plan.isActive ? (kGreenBg, kGreen) : (kGrayBg, kGrayFg);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              const CircleAvatar(
                                  radius: 17,
                                  backgroundColor: kPurpleBg,
                                  child: Icon(Icons.workspace_premium_outlined, size: 17, color: kPurple)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(plan.name,
                                          style: const TextStyle(
                                              fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                      Text(
                                          plan.priceMonthly <= 0
                                              ? 'Free'
                                              : '${plan.priceMonthly.toStringAsFixed(0)} ${plan.currency}/month',
                                          style: const TextStyle(fontSize: 11, color: kMuted)),
                                    ]),
                              ),
                              StatusBadge(plan.isActive ? 'Selling' : 'Hidden', bg, fg),
                              const SizedBox(width: 8),
                              InkWell(
                                  onTap: () => _openForm(plan: plan),
                                  child: const Icon(Icons.edit_outlined, size: 19, color: kBlue)),
                              const SizedBox(width: 8),
                              InkWell(
                                  onTap: () => _toggleActive(plan),
                                  child: Icon(
                                      plan.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 19,
                                      color: plan.isActive ? kRed : kGreen)),
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

class _PlanFormSheet extends StatefulWidget {
  final AdminPlan? plan;
  const _PlanFormSheet({this.plan});

  @override
  State<_PlanFormSheet> createState() => _PlanFormSheetState();
}

class _PlanFormSheetState extends State<_PlanFormSheet> {
  late final _name = TextEditingController(text: widget.plan?.name ?? '');
  late final _price = TextEditingController(
      text: widget.plan == null ? '' : widget.plan!.priceMonthly.toStringAsFixed(0));
  late final _currency = TextEditingController(text: widget.plan?.currency ?? 'VND');
  late final _features = TextEditingController(text: widget.plan?.features ?? '');
  bool _isSaving = false;
  String? _error;

  bool get _isEdit => widget.plan != null;

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.trim());
    if (name.isEmpty || price == null || price < 0) {
      setState(() => _error = 'Enter a valid name and a non-negative price.');
      return;
    }
    setState(() {
      _error = null;
      _isSaving = true;
    });
    try {
      if (_isEdit) {
        await ApiClient.instance.updateAdminPlan(
          widget.plan!.id,
          name: name,
          priceMonthly: price,
          currency: _currency.text.trim().isEmpty ? 'VND' : _currency.text.trim(),
          features: _features.text.trim().isEmpty ? null : _features.text.trim(),
        );
      } else {
        await ApiClient.instance.createAdminPlan(
          name: name,
          priceMonthly: price,
          currency: _currency.text.trim().isEmpty ? 'VND' : _currency.text.trim(),
          features: _features.text.trim().isEmpty ? null : _features.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isEdit ? 'Edit plan' : 'New plan',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kInk)),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Plan name (e.g. Pro)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 2,
              child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: kInk),
                  decoration: adminInput('Price / month')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                  controller: _currency,
                  style: const TextStyle(color: kInk),
                  decoration: adminInput('Currency')),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _features,
              maxLines: 4,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Features (one per line, optional)')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: kRed, fontSize: 12)),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSaving ? 'Saving...' : 'Save plan',
            onPressed: _isSaving ? () {} : _save,
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
