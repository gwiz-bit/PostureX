/// Gói người dùng đang dùng (`GET /api/v1/subscriptions/me`), null nếu chưa mua.
class UserSubscription {
  const UserSubscription({
    required this.id,
    required this.planId,
    required this.planName,
    required this.status,
    required this.startDate,
    required this.autoRenew,
    this.endDate,
    this.daysLeft,
  });

  final int id;
  final int planId;
  final String planName;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;

  /// False = người dùng đã huỷ gia hạn. Gói **vẫn chạy** tới [endDate] rồi mới
  /// tự hết hạn — huỷ không cắt quyền ngay.
  final bool autoRenew;

  /// Số ngày còn lại, do backend tính (client tự tính dễ sai múi giờ).
  final int? daysLeft;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as int,
      planId: json['plan_id'] as int,
      planName: json['plan_name'] as String,
      status: json['status'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] == null
          ? null
          : DateTime.parse(json['end_date'] as String),
      autoRenew: json['auto_renew'] as bool,
      daysLeft: json['days_left'] as int?,
    );
  }
}
