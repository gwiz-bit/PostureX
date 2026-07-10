import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../models/notification.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});
  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int _chip = 2;
  final _chips = const ['Day', 'Week', 'Month', 'Year'];
  final _barHeights = const [38.0, 46.0, 42.0, 58.0, 66.0, 80.0];
  final _barLabels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  final _tx = const [
    Transaction(
        initials: 'NM',
        avatarBg: kBlueBg,
        avatarFg: kBlue,
        name: 'Nguyen Minh',
        plan: 'Annual Premium',
        amount: '+799,000₫',
        status: 'Success'),
    Transaction(
        initials: 'TL',
        avatarBg: kPurpleBg,
        avatarFg: kPurple,
        name: 'Tran Lan',
        plan: 'Monthly Premium',
        amount: '+99,000₫',
        status: 'Success'),
    Transaction(
        initials: 'PH',
        avatarBg: kCoralBg,
        avatarFg: kCoral,
        name: 'Pham Huy',
        plan: 'Monthly Premium',
        amount: '−99,000₫',
        status: 'Refund'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Revenue Management', 'July, 2026', actions: [
        IconButton(
            tooltip: 'Export report',
            onPressed: () => showToast(context, 'Excel report exported'),
            icon: const Icon(Icons.download_outlined)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildChips(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: 'Total revenue',
                    value: '48.5M ₫',
                    sub: '+12% vs last month')),
            const SizedBox(width: 12),
            Expanded(
                child: MetricCard(
                    label: 'MRR',
                    value: '32.1M ₫',
                    sub: '+8% vs last month')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: MetricCard(
                    label: 'Paid users',
                    value: '412',
                    sub: '+37 new users')),
            const SizedBox(width: 12),
            Expanded(
                child: MetricCard(
                    label: 'Transactions',
                    value: '186',
                    sub: '3 refunds',
                    subColor: kRed)),
          ]),
          const SizedBox(height: 16),
          _buildChart(),
          const SizedBox(height: 16),
          const SectionLabel('Recent transactions'),
          ListCard(rows: _tx.map(_txRow).toList()),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Row(
      children: List.generate(_chips.length, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _chip = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: _chip == i ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: Text(_chips[i],
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _chip == i ? Colors.white : kMuted))),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildChart() {
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Revenue last 6 months',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(6, (i) {
              final isLast = i == 5;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: _barHeights[i],
                        decoration: BoxDecoration(
                            color: isLast
                                ? AppColors.primary
                                : AppColors.surfaceElevated,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6))),
                      ),
                      const SizedBox(height: 4),
                      Text(_barLabels[i],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isLast ? FontWeight.w600 : FontWeight.w400,
                              color: isLast ? AppColors.primary : kMuted)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }

  Widget _txRow(Transaction t) {
    final refund = t.status == 'Refund';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        CircleAvatar(
            radius: 17,
            backgroundColor: t.avatarBg,
            child: Text(t.initials,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: t.avatarFg))),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
          Text(t.plan, style: const TextStyle(fontSize: 11, color: kMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(t.amount,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: refund ? kRed : kInk)),
          Text(t.status,
              style: TextStyle(fontSize: 11, color: refund ? kRed : kGreen)),
        ]),
      ]),
    );
  }
}
