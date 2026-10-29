import 'app_locale.dart';

/// Quy tắc mật khẩu mới — phải khớp `validate_password_strength` ở
/// `backend/app/schemas/validators.py` (đăng ký, đặt lại và đổi mật khẩu).
/// Đổi một nơi thì sửa cả nơi kia; không dùng cho đăng nhập vì tài khoản cũ
/// có thể còn mật khẩu yếu.
///
/// Trả về `null` nếu hợp lệ, ngược lại là thông báo lỗi đã dịch.
String? validateNewPassword(String value) {
  if (value.length < 8) return AppLocale.t('validation_min_8_chars');
  final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
  final hasLower = RegExp(r'[a-z]').hasMatch(value);
  final hasDigit = RegExp(r'\d').hasMatch(value);
  final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  if (!(hasUpper && hasLower && hasDigit && hasSpecial)) {
    return AppLocale.t('validation_password_strength');
  }
  return null;
}
