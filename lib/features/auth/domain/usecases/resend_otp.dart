import '../repositories/session_repository.dart';

class ResendOtp {
  const ResendOtp(this._repository);

  final SessionRepository _repository;

  Future<void> call({required String email}) => _repository.resendOtp(email: email);
}
