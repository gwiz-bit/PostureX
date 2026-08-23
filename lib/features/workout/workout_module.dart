import '../../services/api_client.dart';
import 'data/datasources/workout_remote_data_source.dart';
import 'data/repositories/workout_repository_impl.dart';
import 'domain/repositories/workout_repository.dart';
import 'domain/usecases/create_workout.dart';
import 'domain/usecases/get_workout_stats.dart';
import 'domain/usecases/get_workouts.dart';
import 'presentation/controllers/workout_controller.dart';

/// Manual composition root for the Workout feature. No DI framework — just
/// plain factory functions wiring data source → repository → use cases,
/// matching the rest of this codebase's dependency-free style.
class WorkoutModule {
  WorkoutModule._();

  static WorkoutRepository _repository() =>
      WorkoutRepositoryImpl(WorkoutRemoteDataSource(ApiClient.instance));

  static GetWorkouts getWorkouts() => GetWorkouts(_repository());

  static CreateWorkout createWorkout() => CreateWorkout(_repository());

  static const GetWorkoutStats getWorkoutStats = GetWorkoutStats();

  /// A fresh controller instance — screens own their own (see
  /// `ProgressScreen`), matching the existing per-screen `reload()` pattern
  /// `MainShell` already uses instead of a shared/global controller.
  static WorkoutController controller() => WorkoutController(
        getWorkouts: getWorkouts(),
        createWorkout: createWorkout(),
        getWorkoutStats: getWorkoutStats,
      );
}
