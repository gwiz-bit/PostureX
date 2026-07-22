import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../models/admin_models.dart';
import '../../theme/app_theme.dart';
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
      final stats = await ApiClient.instance.fetchAdminRevenue();
      if (!mounted) return;
      setState(() => _stats = stats);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(double v, String currency) =>
      '${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} $currency';

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: adminAppBar('Revenue', 'Payments collected via MoMo'),
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
                : stats == null
                    ? const SizedBox()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(children: [
                            Expanded(
                                child: MetricCard(
                                    label: 'Total revenue',
                                    value: _money(stats.totalRevenue, stats.recentPayments.isNotEmpty
                                        ? stats.recentPayments.first.currency
                                        : 'VND'))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: MetricCard(
                                    label: 'Paid transactions',
                                    value: '${stats.totalPaidPayments}')),
                          ]),
                          const SizedBox(height: 20),
                          const SectionLabel('Revenue by plan'),
                          if (stats.byPlan.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No paid transactions yet.', style: TextStyle(color: kMuted)),
                            )
                          else
                            ListCard(
                              rows: stats.byPlan.map((p) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  child: Row(children: [
                                    const CircleAvatar(
                                        radius: 17,
                                        backgroundColor: kGreenBg,
                                        child: Icon(Icons.pie_chart_outline, size: 17, color: kGreen)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.planName,
                                                style: const TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                            Text('${p.paymentCount} payments',
                                                style: const TextStyle(fontSize: 11, color: kMuted)),
                                          ]),
                                    ),
                                    Text(_money(p.revenue, 'VND'),
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                                  ]),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          const SectionLabel('Recent transactions'),
                          if (stats.recentPayments.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text('No transactions yet.', style: TextStyle(color: kMuted)),
                            )
                          else
                            ListCard(
                              rows: stats.recentPayments.map((p) {
                                final (bg, fg) = switch (p.status) {
                                  'Completed' => (kGreenBg, kGreen),
                                  'Failed' => (kRedBg, kRed),
                                  _ => (kAmberBg, kAmber),
                                };
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  child: Row(children: [
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.userEmail,
                                                style: const TextStyle(
                                                    fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
                                                overflow: TextOverflow.ellipsis),
                                            Text('${p.planName} · ${_money(p.amount, p.currency)}',
                                                style: const TextStyle(fontSize: 11, color: kMuted)),
                                          ]),
                                    ),
                                    StatusBadge(p.status, bg, fg),
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
