import '../../../../features/admin_exercises/domain/entities/admin_exercise.dart';
import '../../../../services/api_client.dart';
import '../../domain/entities/exercise.dart';

/// Wraps [ApiClient]'s `GET /exercises` — the backend reuses its admin
/// `AdminExercise` DTO for this public endpoint, so mapping down to the
/// feature's own [Exercise] entity happens here, not in the presentation
/// layer.
class ExerciseRemoteDataSource {
  const ExerciseRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<Exercise>> fetchExercises() async {
    final admin = await _client.fetchExercises();
    return admin.map(_toEntity).toList();
  }

  Exercise _toEntity(AdminExercise e) => Exercise(
        id: e.id,
        name: e.name,
        description: e.description,
        category: e.category,
        difficulty: e.difficulty,
        demoVideoUrl: e.demoVideoUrl,
        muscleGroups: e.muscleGroups,
        supportsAnalysis: e.supportsAnalysis,
      );
}
