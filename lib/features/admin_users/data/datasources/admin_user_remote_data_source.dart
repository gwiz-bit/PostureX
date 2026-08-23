import '../../../../services/api_client.dart';
import '../../domain/entities/admin_user.dart';

class AdminUserRemoteDataSource {
  const AdminUserRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AdminUser>> fetchUsers() => _client.fetchAdminUsers();

  Future<AdminUser> updateUser(int userId, {String? fullName, bool? isActive, bool? isAdmin}) {
    return _client.updateAdminUser(userId, fullName: fullName, isActive: isActive, isAdmin: isAdmin);
  }

  Future<void> deleteUser(int userId) => _client.deleteAdminUser(userId);
}
