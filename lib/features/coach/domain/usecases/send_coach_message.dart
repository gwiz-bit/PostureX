import '../repositories/coach_repository.dart';

class SendCoachMessage {
  const SendCoachMessage(this._repository);

  final CoachRepository _repository;

  Future<String> call({required String message}) {
    return _repository.sendMessage(message: message);
  }
}
