import '../repositories/admin_user_repository.dart';

class DeleteAdminUser {
  const DeleteAdminUser(this._repository);

  final AdminUserRepository _repository;

  Future<void> call(int userId) => _repository.deleteUser(userId);
}
