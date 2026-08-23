import '../../../../core/errors/failures.dart';
import '../../../../models/auth_response.dart';
import '../../../../models/user_session.dart';
import '../../../../services/api_exception.dart';
import '../../../../services/google_auth_service.dart';
import '../../../../services/token_storage.dart';
import '../../domain/entities/auth_session_result.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// Bridges the new Auth feature to the pre-existing global session
/// (`UserSession`/`TokenStorage`) — deliberately NOT rewriting those; every
/// other screen (Profile, Home, ...) still reads `UserSession` directly, so
/// this repository keeps populating it exactly as the old screen code used
/// to. This is the strangler-fig seam: new code (screens, use cases) depends
/// only on [SessionRepository]; `UserSession` becomes an implementation
/// detail hidden behind it instead of something every screen orchestrates
/// by hand.
class SessionRepositoryImpl implements SessionRepository {
  const SessionRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  Future<AuthSessionResult> _establish(
    AuthResponse auth, {
    required bool hasCompletedOnboarding,
  }) async {
    UserSession.accessToken = auth.accessToken;
    final profile = await _remote.fetchMe();
    UserSession.applyAuthSession(
      userId: profile.id,
      email: profile.email,
      fullName: profile.fullName,
      accessToken: auth.accessToken,
      isAdmin: profile.isAdmin,
    );
    try {
      await TokenStorage.saveSession(
        accessToken: auth.accessToken,
        userId: profile.id,
        email: profile.email,
      );
    } catch (_) {
      // Persisting the session is best-effort — the user stays logged in
      // for this run even if secure storage is unavailable.
    }
    UserSession.hasCompletedOnboarding = hasCompletedOnboarding;
    return AuthSessionResult(
      isAdmin: profile.isAdmin,
      isNewUser: auth.isNewUser,
      fullName: profile.fullName,
    );
  }

  @override
  Future<AuthSessionResult> login({required String email, required String password}) {
    return _run(() async {
      final auth = await _remote.login(email: email, password: password);
      return _establish(auth, hasCompletedOnboarding: true);
    });
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _run(() => _remote.register(email: email, password: password, fullName: fullName));
  }

  @override
  Future<AuthSessionResult> verifyOtp({
    required String email,
    required String otpCode,
    required bool isFreshRegistration,
  }) {
    return _run(() async {
      final auth = await _remote.verifyOtp(email: email, otpCode: otpCode);
      return _establish(auth, hasCompletedOnboarding: !isFreshRegistration);
    });
  }

  @override
  Future<void> resendOtp({required String email}) => _run(() => _remote.resendOtp(email: email));

  @override
  Future<AuthSessionResult?> loginWithGoogle() async {
    final idToken = await GoogleAuthService.signInAndGetIdToken();
    if (idToken == null) return null; // user dismissed the account picker
    return _run(() async {
      final auth = await _remote.loginWithGoogle(idToken: idToken);
      return _establish(auth, hasCompletedOnboarding: !auth.isNewUser);
    });
  }

  @override
  Future<void> forgotPassword({required String email}) {
    return _run(() => _remote.forgotPassword(email: email));
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _run(() => _remote.resetPassword(
          token: token,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        ));
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
