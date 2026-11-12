import '../repositories/session_repository.dart';

class ResetPassword {
  const ResetPassword(this._repository);

  final SessionRepository _repository;

  Future<void> call({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _repository.resetPassword(
      email: email,
      code: code,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }
}
