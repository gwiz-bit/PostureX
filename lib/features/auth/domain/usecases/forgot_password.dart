import '../repositories/session_repository.dart';

class ForgotPassword {
  const ForgotPassword(this._repository);

  final SessionRepository _repository;

  Future<void> call({required String email}) => _repository.forgotPassword(email: email);
}
