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
///   devices instead need the host machine's real LAN IP — see docs/SETUP.md).
class ApiConfig {
  ApiConfig._();

  static bool get _isAndroidEmulator => !kIsWeb && Platform.isAndroid;

  /// Production override — pass at build time, e.g.:
  /// `flutter build ios --dart-define=API_BASE_URL=https://api.posturex.app`
  /// Empty by default, which falls back to the local-dev URLs below so
  /// nothing changes for `flutter run` during development.
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    return _isAndroidEmulator ? 'http://10.0.2.2:9000' : 'http://localhost:9000';
  }

  static String get wsUrl {
    if (_baseUrlOverride.isNotEmpty) {
      final uri = Uri.parse(_baseUrlOverride);
      return uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws').toString();
    }
    return _isAndroidEmulator ? 'ws://10.0.2.2:9000' : 'ws://localhost:9000';
  }

  /// The "Web application" OAuth 2.0 client ID from Google Cloud Console
  /// (Credentials page) — NOT the Android client ID. Passed as
  /// `GoogleSignIn(serverClientId: ...)` so the ID token it returns has an
  /// `aud` claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
  static const String googleWebClientId =
      '879931217481-eeqak275h11nji6v93j8a9s65rc7pjt3.apps.googleusercontent.com';
}
