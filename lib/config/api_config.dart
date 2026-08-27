/// Backend connection settings.
///
/// Mặc định trỏ thẳng vào server thật trên VPS. Ai cần chạy backend ngay
/// trên máy mình thì truyền địa chỉ đó lúc build:
///
///     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9000    # Android emulator
///     flutter run --dart-define=API_BASE_URL=http://localhost:9000   # Windows/web
///
/// `10.0.2.2` là bí danh máy ảo Android dùng để gọi về `localhost` của máy
/// dev — máy ảo có loopback riêng nên gõ `localhost` sẽ trỏ ngược vào chính nó.
///
/// **Vì sao mặc định là server thật, không phải máy local.** Trước đây thì
/// ngược lại, và nó gây hai vấn đề:
///
/// 1. `API_BASE_URL` là hằng số BIÊN DỊCH, không phải cấu hình lúc chạy — mỗi
///    lần build đều phải truyền lại. Quên một lần là app im lặng trỏ về
///    `10.0.2.2` và báo "Could not reach the server" dù server vẫn sống. Cả
///    nhóm đã mất thời gian vì đúng chuyện này nhiều lần.
/// 2. Nghiêm trọng hơn: nếu người đóng gói bản phát hành quên cờ, app lên
///    store sẽ trỏ vào `10.0.2.2` — địa chỉ chỉ có nghĩa trên máy ảo — và
///    hỏng với 100% người dùng, phải chờ duyệt bản mới mới sửa được. Đảo mặc
///    định làm hướng hỏng an toàn hơn: quên cờ thì người chịu là dev chạy
///    backend local, và họ phát hiện ngay trên máy mình.
///
/// **Cần đổi trước khi phát hành thật:** giá trị dưới đây là IP trần. Đổi
/// VPS hoặc hết hạn nhà cung cấp là mọi app đã cài đều chết, vì IP nằm cứng
/// trong bản build. Ngoài ra iOS chặn `http://` (App Transport Security), và
/// nhiều mạng trường học/công ty chặn cổng lạ như 9000. Khi có domain +
/// HTTPS thì đổi hằng số này thành `https://api.<tên miền>` — lúc đó chuyển
/// máy chủ chỉ cần trỏ lại DNS, không phải phát hành lại app.
library;

class ApiConfig {
  ApiConfig._();

  /// Server thật. Xem chú thích đầu file về việc phải đổi sang domain HTTPS
  /// trước khi phát hành.
  static const String _defaultBaseUrl = 'http://103.179.172.246:9000';

  /// Ghi đè lúc build, vd `--dart-define=API_BASE_URL=http://10.0.2.2:9000`.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl =>
      _baseUrlOverride.isNotEmpty ? _baseUrlOverride : _defaultBaseUrl;

  /// Cùng host với [baseUrl], chỉ đổi scheme sang ws/wss — dùng cho endpoint
  /// phân tích tư thế thời gian thực. Suy ra từ [baseUrl] thay vì tự viết
  /// lại địa chỉ, để hai bên không bao giờ lệch nhau.
  static String get wsUrl {
    final uri = Uri.parse(baseUrl);
    return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString();
  }

  /// The "Web application" OAuth 2.0 client ID from Google Cloud Console
  /// (Credentials page) — NOT the Android client ID. Passed as
  /// `GoogleSignIn(serverClientId: ...)` so the ID token it returns has an
  /// `aud` claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
  static const String googleWebClientId =
      '879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com';
}
