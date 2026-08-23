import '../repositories/admin_notification_repository.dart';

class SendBroadcast {
  const SendBroadcast(this._repository);

  final AdminNotificationRepository _repository;

  Future<int> call({required String title, String? body}) {
    return _repository.sendBroadcast(title: title, body: body);
  }
}
