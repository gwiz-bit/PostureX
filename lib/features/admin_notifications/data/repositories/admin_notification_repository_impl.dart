import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/broadcast_history_item.dart';
import '../../domain/repositories/admin_notification_repository.dart';
import '../datasources/admin_notification_remote_data_source.dart';

class AdminNotificationRepositoryImpl implements AdminNotificationRepository {
  const AdminNotificationRepositoryImpl(this._remote);

  final AdminNotificationRemoteDataSource _remote;

  @override
  Future<List<BroadcastHistoryItem>> getBroadcastHistory() => _run(_remote.fetchBroadcastHistory);

  @override
  Future<int> sendBroadcast({required String title, String? body}) {
    return _run(() => _remote.sendBroadcast(title: title, body: body));
  }

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
