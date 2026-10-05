/// Cờ bật/tắt tính năng ở thời điểm biên dịch.
///
/// [paymentsEnabled] = false: bản đưa lên Google Play không bán gói trả phí, nên
/// không phải dùng Google Play Billing (chính sách Payments của Play chỉ áp dụng
/// khi app bán tính năng số) và mọi người tập không giới hạn. Bật lại thì phải
/// (1) bật `PAYMENTS_ENABLED` trong `.env` của backend và (2) chuyển sang Google
/// Play Billing thay vì MoMo trước khi phát hành lên Play.
class AppFeatures {
  AppFeatures._();

  static const bool paymentsEnabled = false;
}
