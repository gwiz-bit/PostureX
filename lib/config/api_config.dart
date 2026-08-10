import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Backend connection settings.
///
/// The FastAPI backend is expected to be running locally on port 9000
/// (`uvicorn app.main:app --reload --port 9000`). The host to reach it at
/// depends on *where the app itself is running*, not the backend:
/// - Android emulator: `10.0.2.2` (the emulator's alias for the host
///   machine's `localhost` — the emulator has its own separate loopback,
///   so plain `localhost` would point back at the emulator itself).
/// - Windows/web/desktop, or a physical device: `localhost` (physical
///   devices instead need the host machine's real LAN IP — see SETUP.md).
class ApiConfig {
  ApiConfig._();

  static bool get _isAndroidEmulator => !kIsWeb && Platform.isAndroid;

  static String get baseUrl =>
      _isAndroidEmulator ? 'http://10.0.2.2:9000' : 'http://localhost:9000';

  static String get wsUrl => _isAndroidEmulator ? 'ws://10.0.2.2:9000' : 'ws://localhost:9000';

  /// The "Web application" OAuth 2.0 client ID from Google Cloud Console
  /// (Credentials page) — NOT the Android client ID. Passed as
  /// `GoogleSignIn(serverClientId: ...)` so the ID token it returns has an
  /// `aud` claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
  static const String googleWebClientId =
      '879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com';
}
