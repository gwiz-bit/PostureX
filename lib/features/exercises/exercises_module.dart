import '../../services/api_client.dart';
import 'data/datasources/exercise_remote_data_source.dart';
import 'data/repositories/exercise_repository_impl.dart';
import 'domain/repositories/exercise_repository.dart';
import 'domain/usecases/get_exercises.dart';
import 'presentation/controllers/exercises_controller.dart';

/// Manual composition root for the Exercises feature — same pattern as
/// `WorkoutModule`/`VideoModule`, no DI framework.
class ExercisesModule {
  ExercisesModule._();

  static ExerciseRepository _repository() =>
      ExerciseRepositoryImpl(ExerciseRemoteDataSource(ApiClient.instance));

  static GetExercises getExercises() => GetExercises(_repository());

  static ExercisesController controller() =>
      ExercisesController(getExercises: getExercises());
}
