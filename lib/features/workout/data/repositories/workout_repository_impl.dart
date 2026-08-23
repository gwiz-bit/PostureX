import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/workout.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_remote_data_source.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl(this._remote);

  final WorkoutRemoteDataSource _remote;

  @override
  Future<List<Workout>> getWorkouts() async {
    try {
      return await _remote.fetchWorkouts();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }

  @override
  Future<Workout> createWorkout({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  }) async {
    try {
      return await _remote.createWorkout(
        exercise: exercise,
        totalReps: totalReps,
        durationSeconds: durationSeconds,
        accuracyScore: accuracyScore,
        startedAt: startedAt,
      );
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
