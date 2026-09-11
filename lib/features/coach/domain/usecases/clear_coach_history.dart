import '../repositories/coach_repository.dart';

class ClearCoachHistory {
  const ClearCoachHistory(this._repository);

  final CoachRepository _repository;

  Future<void> call() => _repository.clearHistory();
}
