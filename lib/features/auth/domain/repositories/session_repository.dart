import '../entities/auth_session_result.dart';

abstract class SessionRepository {
  Future<AuthSessionResult> login({required String email, required String password});

  /// Creates the account (unverified) and triggers an OTP email — the
  /// account cannot log in until [verifyOtp] succeeds.
  Future<void> register({required String email, required String password, required String fullName});

  Future<AuthSessionResult> verifyOtp({
    required String email,
    required String otpCode,
    required bool isFreshRegistration,
  });

  Future<void> resendOtp({required String email});

  /// Returns `null` if the user dismissed the Google account picker.
  Future<AuthSessionResult?> loginWithGoogle();

  Future<void> forgotPassword({required String email});

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  });
}
