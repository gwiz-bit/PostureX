import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/coach_repository.dart';
import '../datasources/coach_remote_data_source.dart';

class CoachRepositoryImpl implements CoachRepository {
  const CoachRepositoryImpl(this._remote);

  final CoachRemoteDataSource _remote;

  @override
  Future<String> sendMessage({required String message, required List<ChatMessage> history}) async {
    try {
      return await _remote.sendMessage(message: message, history: history);
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
