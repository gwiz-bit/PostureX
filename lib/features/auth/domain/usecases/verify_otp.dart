import '../entities/auth_session_result.dart';
import '../repositories/session_repository.dart';

class VerifyOtp {
  const VerifyOtp(this._repository);

  final SessionRepository _repository;

  Future<AuthSessionResult> call({
    required String email,
    required String otpCode,
    required bool isFreshRegistration,
  }) {
    return _repository.verifyOtp(
      email: email,
      otpCode: otpCode,
      isFreshRegistration: isFreshRegistration,
    );
  }
}
