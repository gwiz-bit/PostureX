import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../../models/plan.dart';
import '../models/admin_models.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});
  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  RevenueStats? _stats;
  Map<int, String> _planNames = {};
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
        ApiClient.instance.fetchAdminRevenue(),
        ApiClient.instance.fetchAdminPlans(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as RevenueStats;
        _planNames = {for (final p in results[1] as List<Plan>) p.id: p.name};
      });
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatVnd(int vnd) {
    final s = vnd.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return '${buffer.toString()}₫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Revenue Management', 'Mock payments · live totals'),
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
                      Row(children: [
                        Expanded(
                            child: MetricCard(
                                label: 'Total revenue',
                                value: _formatVnd(_stats!.totalRevenueVnd))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: MetricCard(
                                label: 'Transactions', value: '${_stats!.totalTransactions}')),
                      ]),
                      const SizedBox(height: 16),
                      const SectionLabel('Revenue by plan'),
                      if (_stats!.revenueByPlan.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No revenue yet', style: TextStyle(color: kMuted))),
                        )
                      else
                        ListCard(
                          rows: _stats!.revenueByPlan.entries.map((e) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(children: [
                                Expanded(
                                    child: Text(e.key,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: kInk))),
                                Text(_formatVnd(e.value),
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                              ]),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      const SectionLabel('Recent transactions'),
                      if (_stats!.recentTransactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: Text('No transactions yet', style: TextStyle(color: kMuted))),
                        )
                      else
                        ListCard(rows: _stats!.recentTransactions.map(_txRow).toList()),
                    ],
                  ),
      ),
    );
  }

  Widget _txRow(AdminTransaction t) {
    final failed = t.status != 'success';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(children: [
        CircleAvatar(
            radius: 17,
            backgroundColor: kBlueBg,
            child: Text('#${t.userId}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kBlue))),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_planNames[t.planId] ?? 'Plan #${t.planId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
          Text(t.paymentMethod, style: const TextStyle(fontSize: 11, color: kMuted)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+${_formatVnd(t.amountVnd)}',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: failed ? kRed : kInk)),
          Text(t.status, style: TextStyle(fontSize: 11, color: failed ? kRed : kGreen)),
        ]),
      ]),
    );
  }
}
