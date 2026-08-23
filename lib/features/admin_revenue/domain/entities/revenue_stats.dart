import 'admin_payment.dart';
import 'revenue_by_plan.dart';

class RevenueStats {
  const RevenueStats({
    required this.totalRevenue,
    required this.totalPaidPayments,
    required this.byPlan,
    required this.recentPayments,
  });

  final double totalRevenue;
  final int totalPaidPayments;
  final List<RevenueByPlan> byPlan;
  final List<AdminPayment> recentPayments;

  /// Single source of truth for the currency shown across this screen —
  /// the backend doesn't send a currency on the per-plan breakdown, so
  /// both totals and the by-plan rows derive it from here instead of one
  /// hardcoding 'VND' independently of the other (that mismatch was a real
  /// bug in the pre-migration admin screen).
  String get currency => recentPayments.isNotEmpty ? recentPayments.first.currency : 'VND';

  factory RevenueStats.fromJson(Map<String, dynamic> json) => RevenueStats(
        totalRevenue: double.parse(json['total_revenue'].toString()),
        totalPaidPayments: json['total_paid_payments'] as int,
        byPlan: (json['by_plan'] as List)
            .map((e) => RevenueByPlan.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentPayments: (json['recent_payments'] as List)
            .map((e) => AdminPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
