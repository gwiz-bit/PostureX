/// Backend connection settings.
///
/// `10.0.2.2` is the Android emulator's alias for the host machine's
/// `localhost` — the FastAPI backend is expected to be running locally on
/// port 9000 (`uvicorn app.main:app --reload --port 9000`).
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'http://10.0.2.2:9000';
  static const String wsUrl = 'ws://10.0.2.2:9000';

  /// The "Web application" OAuth 2.0 client ID from Google Cloud Console
  /// (Credentials page) — NOT the Android client ID. Passed as
  /// `GoogleSignIn(serverClientId: ...)` so the ID token it returns has an
  /// `aud` claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
  /// TODO: fill in once created — see lib/backend/.env's GOOGLE_CLIENT_ID.
  static const String googleWebClientId =
      '879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com';
}
