import '../repositories/coach_repository.dart';

class ReportCoachMessage {
  const ReportCoachMessage(this._repository);

  final CoachRepository _repository;

  Future<void> call({required String reason, required String content}) {
    return _repository.reportMessage(reason: reason, content: content);
  }
}
