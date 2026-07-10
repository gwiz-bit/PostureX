import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';

/// Wraps `google_sign_in`'s native account picker (shows Google accounts
/// already added on the device/emulator) and hands back the ID token that
/// the backend's `POST /api/v1/auth/google` verifies.
///
/// [ApiConfig.googleWebClientId] must be the "Web application" OAuth
/// client ID (not the Android one) — passing it as `serverClientId` is
/// what makes `authentication.idToken` non-null and gives it an `aud`
/// claim the backend's `GOOGLE_CLIENT_ID` (same value) can verify.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _instance = GoogleSignIn(
    serverClientId: ApiConfig.googleWebClientId,
    scopes: const ['email'],
  );

  /// Returns `null` if the user dismissed the account picker without
  /// choosing an account.
  static Future<String?> signInAndGetIdToken() async {
    final account = await _instance.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  static Future<void> signOut() => _instance.signOut();
}
