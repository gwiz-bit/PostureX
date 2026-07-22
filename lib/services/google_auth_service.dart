import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';

/// Thin interface over the pieces of `google_sign_in` this app uses —
/// swappable (see [GoogleAuthService.backend]) so widget tests don't need
/// a real platform channel: there's no Play Services in the test
/// environment, and the real plugin's calls hang waiting for a response
/// that never comes rather than failing fast.
abstract class GoogleAuthBackend {
  Future<String?> signInAndGetIdToken();
  Future<void> signOut();
  Future<void> disconnect();
}

/// Wraps `google_sign_in`'s native account picker (shows Google accounts
/// already added on the device/emulator) and hands back the ID token that
/// the backend's `POST /api/v1/auth/google` verifies.
///
/// [ApiConfig.googleWebClientId] must be the "Web application" OAuth
/// client ID (not the Android one) — passing it as `serverClientId` is
/// what makes `authentication.idToken` non-null and gives it an `aud`
/// claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
class _RealGoogleAuthBackend implements GoogleAuthBackend {
  final GoogleSignIn _instance = GoogleSignIn(
    serverClientId: ApiConfig.googleWebClientId,
    scopes: const ['email'],
  );

  /// Returns `null` if the user dismissed the account picker without
  /// choosing an account.
  @override
  Future<String?> signInAndGetIdToken() async {
    final account = await _instance.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  @override
  Future<void> signOut() => _instance.signOut();

  /// Fully forgets the signed-in Google account (revokes granted scopes),
  /// unlike [signOut] which only ends the app session — Google Play
  /// Services can still silently reuse the last account on the next
  /// [signInAndGetIdToken] call otherwise, so this is what logout should
  /// call to make the account picker (or "use another account") show up
  /// again next time.
  @override
  Future<void> disconnect() async {
    // Bounded with a timeout so a hung platform channel (bad network or a
    // buggy Play Services state) can never block logout indefinitely.
    try {
      await _instance.disconnect().timeout(const Duration(seconds: 5));
    } catch (_) {
      try {
        await _instance.signOut().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Nothing more we can do locally — logout proceeds regardless.
      }
    }
  }
}

class GoogleAuthService {
  GoogleAuthService._();

  /// Mutable (not `final`) so tests can swap in a no-op [GoogleAuthBackend]
  /// instead of the real plugin — mirrors `ApiClient.instance` and
  /// `TokenStorage.backend`.
  static GoogleAuthBackend backend = _RealGoogleAuthBackend();

  static Future<String?> signInAndGetIdToken() => backend.signInAndGetIdToken();

  static Future<void> signOut() => backend.signOut();

  static Future<void> disconnect() => backend.disconnect();
}
