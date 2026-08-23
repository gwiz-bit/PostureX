/// Gói cước bán ra (`GET /api/v1/subscriptions/plans`).
///
/// Giá do backend trả về, **không hardcode ở client** — trước đây màn
/// Subscription ghi cứng 199k/299k trong khi database bán 99k/199k.
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthly,
    required this.currency,
    this.features,
  });

  final int id;
  final String name;
  final double priceMonthly;
  final String currency;
  final String? features;

  bool get isFree => priceMonthly <= 0;

  /// Danh sách tính năng: backend lưu một chuỗi, ngăn cách bằng dấu phẩy.
  List<String> get featureList {
    if (features == null || features!.trim().isEmpty) return const [];
    return features!.split(',').map((f) => f.trim()).where((f) => f.isNotEmpty).toList();
  }

  /// "99.000₫" — dấu chấm ngăn cách hàng nghìn theo cách viết của người Việt.
  String get formattedPrice {
    if (isFree) return '0₫';
    final whole = priceMonthly.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('.');
      buffer.write(whole[i]);
    }
    return '$buffer₫';
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as int,
      name: json['name'] as String,
      // Backend trả DECIMAL, JSON hoá thành chuỗi ("99000.00") chứ không phải số.
      priceMonthly: double.parse(json['price_monthly'].toString()),
      currency: json['currency'] as String,
      features: json['features'] as String?,
    );
  }
}
