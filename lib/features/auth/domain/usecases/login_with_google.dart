import '../entities/auth_session_result.dart';
import '../repositories/session_repository.dart';

class LoginWithGoogle {
  const LoginWithGoogle(this._repository);

  final SessionRepository _repository;

  /// Returns `null` if the user dismissed the Google account picker.
  Future<AuthSessionResult?> call() => _repository.loginWithGoogle();
}
