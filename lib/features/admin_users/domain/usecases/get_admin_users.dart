import '../entities/admin_user.dart';
import '../repositories/admin_user_repository.dart';

class GetAdminUsers {
  const GetAdminUsers(this._repository);

  final AdminUserRepository _repository;

  Future<List<AdminUser>> call() => _repository.getUsers();
}
