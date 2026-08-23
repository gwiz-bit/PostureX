import '../../services/api_client.dart';
import 'data/datasources/admin_user_remote_data_source.dart';
import 'data/repositories/admin_user_repository_impl.dart';
import 'domain/repositories/admin_user_repository.dart';
import 'domain/usecases/delete_admin_user.dart';
import 'domain/usecases/get_admin_users.dart';
import 'domain/usecases/update_admin_user.dart';

class AdminUsersModule {
  AdminUsersModule._();

  static AdminUserRepository _repository() =>
      AdminUserRepositoryImpl(AdminUserRemoteDataSource(ApiClient.instance));

  static GetAdminUsers getAdminUsers() => GetAdminUsers(_repository());

  static UpdateAdminUser updateAdminUser() => UpdateAdminUser(_repository());

  static DeleteAdminUser deleteAdminUser() => DeleteAdminUser(_repository());
}
