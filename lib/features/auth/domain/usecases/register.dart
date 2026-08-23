import '../repositories/session_repository.dart';

class Register {
  const Register(this._repository);

  final SessionRepository _repository;

  Future<void> call({required String email, required String password, required String fullName}) {
    return _repository.register(email: email, password: password, fullName: fullName);
  }
}
