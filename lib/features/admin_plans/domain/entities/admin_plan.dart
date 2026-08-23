/// Gói cước quản trị — trỏ vào bảng `SubscriptionPlans` thật (hệ MoMo), khác
/// với model `Plan` cũ (đã orphan, không còn dùng).
class AdminPlan {
  const AdminPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.currency,
    required this.features,
    required this.isActive,
  });

  final int id;
  final String name;
  final double priceMonthly;
  final String currency;
  final String? features;
  final bool isActive;

  factory AdminPlan.fromJson(Map<String, dynamic> json) => AdminPlan(
        id: json['id'] as int,
        name: json['name'] as String,
        // Backend trả DECIMAL, JSON hoá thành chuỗi ("99000.00") chứ không phải số.
        priceMonthly: double.parse(json['price_monthly'].toString()),
        currency: json['currency'] as String,
        features: json['features'] as String?,
        isActive: json['is_active'] as bool,
      );
}
