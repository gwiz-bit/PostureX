/// Kết quả `POST /subscriptions/checkout` — đơn chờ thanh toán + URL MoMo.
class Checkout {
  const Checkout({required this.paymentId, required this.payUrl});

  final int paymentId;
  final String payUrl;

  factory Checkout.fromJson(Map<String, dynamic> json) {
    return Checkout(
      paymentId: json['payment_id'] as int,
      payUrl: json['pay_url'] as String,
    );
  }
}
