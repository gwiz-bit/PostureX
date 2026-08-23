class RevenueByPlan {
  const RevenueByPlan({
    required this.planId,
    required this.planName,
    required this.revenue,
    required this.paymentCount,
  });

  final int planId;
  final String planName;
  final double revenue;
  final int paymentCount;

  factory RevenueByPlan.fromJson(Map<String, dynamic> json) => RevenueByPlan(
        planId: json['plan_id'] as int,
        planName: json['plan_name'] as String,
        revenue: double.parse(json['revenue'].toString()),
        paymentCount: json['payment_count'] as int,
      );
}
