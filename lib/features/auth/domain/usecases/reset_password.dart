import '../repositories/session_repository.dart';

class ResetPassword {
  const ResetPassword(this._repository);

  final SessionRepository _repository;

  Future<void> call({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _repository.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
