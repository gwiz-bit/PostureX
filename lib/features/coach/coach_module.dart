import '../../services/api_client.dart';
import 'data/datasources/coach_remote_data_source.dart';
import 'data/repositories/coach_repository_impl.dart';
import 'domain/repositories/coach_repository.dart';
import 'domain/usecases/send_coach_message.dart';
import 'presentation/controllers/ai_coach_controller.dart';

/// Manual composition root for the AI Coach feature.
class CoachModule {
  CoachModule._();

  static CoachRepository _repository() =>
      CoachRepositoryImpl(CoachRemoteDataSource(ApiClient.instance));

  static AiCoachController controller() =>
      AiCoachController(sendCoachMessage: SendCoachMessage(_repository()));
}
