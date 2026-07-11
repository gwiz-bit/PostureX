/// Backend connection settings.
///
/// The FastAPI backend is expected to be running on the dev machine at port
/// 9000 (`uvicorn app.main:app --reload --host 0.0.0.0 --port 9000`).
///
/// [_host] defaults to `10.0.2.2` — the Android emulator's alias for the host
/// machine's `localhost`. A real phone cannot resolve that, so builds targeting
/// a physical device must pass the dev machine's LAN IP instead:
///
///     flutter build apk --debug --dart-define=API_HOST=192.168.1.9
///
/// Any host used here must also be whitelisted for cleartext HTTP in
/// `android/app/src/main/res/xml/network_security_config.xml`, otherwise
/// Android silently blocks the request.
class ApiConfig {
  ApiConfig._();

  static const String _host = String.fromEnvironment(
    'API_HOST',
    defaultValue: '10.0.2.2',
  );

  static const String baseUrl = 'http://$_host:9000';
  static const String wsUrl = 'ws://$_host:9000';

  /// The "Web application" OAuth 2.0 client ID from Google Cloud Console
  /// (Credentials page) — NOT the Android client ID. Passed as
  /// `GoogleSignIn(serverClientId: ...)` so the ID token it returns has an
  /// `aud` claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
  /// TODO: fill in once created — see lib/backend/.env's GOOGLE_CLIENT_ID.
  static const String googleWebClientId =
      '879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com';
}
