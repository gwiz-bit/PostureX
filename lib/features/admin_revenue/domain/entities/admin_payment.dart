class AdminPayment {
  const AdminPayment({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paidAt,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userEmail;
  final String planName;
  final double amount;
  final String currency;
  final String status;
  final DateTime? paidAt;
  final DateTime createdAt;

  factory AdminPayment.fromJson(Map<String, dynamic> json) => AdminPayment(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        userEmail: json['user_email'] as String,
        planName: json['plan_name'] as String,
        amount: double.parse(json['amount'].toString()),
        currency: json['currency'] as String,
        status: json['status'] as String,
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
