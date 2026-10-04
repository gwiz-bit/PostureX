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
/// **Đã đổi sang domain HTTPS (30/09/2026)** — trước đó giá trị dưới đây là
/// IP trần (`http://103.82.21.150:9000`), có 2 rủi ro: đổi VPS hoặc hết hạn
/// nhà cung cấp là mọi app đã cài đều chết vì IP nằm cứng trong bản build;
/// và iOS chặn `http://` (App Transport Security) nên không phát hành được
/// lên App Store với địa chỉ đó. Giờ trỏ qua `api.posturex1.com` (Nginx +
/// Let's Encrypt trên cùng VPS) — đổi máy chủ sau này chỉ cần trỏ lại DNS,
/// không phải phát hành lại app.
library;

class ApiConfig {
  ApiConfig._();

  /// Server thật — domain HTTPS (`api.posturex1.com`, Nginx reverse-proxy +
  /// Let's Encrypt trên VPS 103.82.21.150), thay cho IP:port thô trước đây.
  /// Đổi sang domain 30/09/2026 để: (1) tránh phải build lại app mỗi khi đổi
  /// VPS — chỉ cần trỏ lại DNS, (2) đáp ứng yêu cầu HTTPS của Google
  /// Play/App Store cho bản phát hành thật. `wsUrl` bên dưới tự suy ra
  /// `wss://` từ `https://` nên không cần sửa gì thêm cho WebSocket.
  static const String _defaultBaseUrl = 'https://api.posturex1.com';

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
      '526667437213-3njik3mv75t4oo7e6s0dijlfdip06d2v.apps.googleusercontent.com';
}
