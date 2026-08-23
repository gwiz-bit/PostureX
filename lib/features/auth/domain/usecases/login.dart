import '../entities/auth_session_result.dart';
import '../repositories/session_repository.dart';

class Login {
  const Login(this._repository);

  final SessionRepository _repository;

  Future<AuthSessionResult> call({required String email, required String password}) {
    return _repository.login(email: email, password: password);
  }
}
