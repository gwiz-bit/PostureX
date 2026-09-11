import '../entities/chat_message.dart';
import '../repositories/coach_repository.dart';

class FetchCoachHistory {
  const FetchCoachHistory(this._repository);

  final CoachRepository _repository;

  Future<List<ChatMessage>> call() => _repository.fetchHistory();
}
