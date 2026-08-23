import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_user_repository.dart';
import '../datasources/admin_user_remote_data_source.dart';

class AdminUserRepositoryImpl implements AdminUserRepository {
  const AdminUserRepositoryImpl(this._remote);

  final AdminUserRemoteDataSource _remote;

  @override
  Future<List<AdminUser>> getUsers() => _run(_remote.fetchUsers);

  @override
  Future<AdminUser> updateUser(int userId, {String? fullName, bool? isActive, bool? isAdmin}) {
    return _run(() => _remote.updateUser(userId, fullName: fullName, isActive: isActive, isAdmin: isAdmin));
  }

  @override
  Future<void> deleteUser(int userId) => _run(() => _remote.deleteUser(userId));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
