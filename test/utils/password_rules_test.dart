import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/utils/app_locale.dart';
import 'package:posturex/utils/password_rules.dart';

/// Khoá hợp đồng với `validate_password_strength` của backend
/// (`backend/app/schemas/validators.py`): nếu hai bên lệch nhau thì form báo
/// hợp lệ nhưng server trả 422.
void main() {
  test('mật khẩu đủ mạnh được chấp nhận', () {
    expect(validateNewPassword('Test1234!'), isNull);
  });

  test('ngắn hơn 8 ký tự bị từ chối kèm thông báo độ dài', () {
    expect(validateNewPassword('Aa1!aaa'), AppLocale.t('validation_min_8_chars'));
  });

  for (final weak in const {
    'thiếu chữ hoa': 'test1234!',
    'thiếu chữ thường': 'TEST1234!',
    'thiếu chữ số': 'TestTest!',
    'thiếu ký tự đặc biệt': 'Test12345',
    'chỉ chữ thường': 'abcdefgh',
  }.entries) {
    test('${weak.key} bị từ chối', () {
      expect(validateNewPassword(weak.value), AppLocale.t('validation_password_strength'));
    });
  }
}
