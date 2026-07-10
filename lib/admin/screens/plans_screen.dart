import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../models/plan.dart';
import '../services/mock_data_service.dart';
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
  final _data = MockDataService.instance;

  Future<void> _stopPlan(Plan p) async {
    final ok = await showConfirmDialog(context, 'Stop selling ${p.name}?',
        'Plan will be hidden from app. Existing users keep access until expiry (data retained).');
    if (ok) {
      setState(() => p.selling = false);
      if (mounted) showToast(context, 'Plan hidden from app');
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
              if (created != null) {
                setState(() => _data.plans.add(created));
                if (mounted) showToast(context, 'New plan saved to DB');
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
              final created = await Navigator.push<Promo>(context,
                  MaterialPageRoute(builder: (_) => const AddPromoScreen()));
              if (created != null) {
                setState(() => _data.promos.insert(0, created));
                if (mounted) showToast(context, 'Promo code created');
              }
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = _data.plans;
    final promos = _data.promos;
    return Scaffold(
      appBar: adminAppBar('Plan Management',
          '${plans.length} plans · ${promos.length} promo codes',
          actions: [
            IconButton(onPressed: _openAddMenu, icon: const Icon(Icons.add))
          ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Plans'),
          ListCard(
            rows: plans.map((p) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  CircleAvatar(
                      radius: 17,
                      backgroundColor: p.iconBg,
                      child: Icon(p.icon, size: 17, color: p.iconFg)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kInk)),
                        Text(p.detail,
                            style: const TextStyle(fontSize: 11, color: kMuted)),
                      ])),
                  StatusBadge(p.selling ? 'Active' : 'Inactive',
                      p.selling ? kGreenBg : kGrayBg,
                      p.selling ? kGreen : kGrayFg),
                  if (p.selling && p.name != 'Free') ...[
                    const SizedBox(width: 8),
                    InkWell(
                        onTap: () => _stopPlan(p),
                        child: const Icon(Icons.block, size: 19, color: kRed)),
                  ],
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Promo codes'),
          ListCard(
            rows: promos.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(m.code,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: kInk)),
                        Text(m.detail,
                            style: const TextStyle(fontSize: 11, color: kMuted)),
                      ])),
                  StatusBadge(m.active ? 'Valid' : 'Expired',
                      m.active ? kGreenBg : kGrayBg,
                      m.active ? kGreen : kGrayFg),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
