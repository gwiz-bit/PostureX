import '../entities/admin_user.dart';
import '../repositories/admin_user_repository.dart';

class UpdateAdminUser {
  const UpdateAdminUser(this._repository);

  final AdminUserRepository _repository;

  Future<AdminUser> call(int userId, {String? fullName, bool? isActive, bool? isAdmin}) {
    return _repository.updateUser(userId, fullName: fullName, isActive: isActive, isAdmin: isAdmin);
  }
}
