import '../entities/admin_user.dart';

abstract class AdminUserRepository {
  Future<List<AdminUser>> getUsers();

  Future<AdminUser> updateUser(int userId, {String? fullName, bool? isActive, bool? isAdmin});

  Future<void> deleteUser(int userId);
}
