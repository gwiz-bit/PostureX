import '../repositories/coach_repository.dart';

class SendCoachMessageStream {
  const SendCoachMessageStream(this._repository);

  final CoachRepository _repository;

  Stream<String> call({required String message}) {
    return _repository.sendMessageStream(message: message);
  }
}
