import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/admin_workout.dart';
import '../../domain/repositories/admin_workout_repository.dart';
import '../datasources/admin_workout_remote_data_source.dart';

class AdminWorkoutRepositoryImpl implements AdminWorkoutRepository {
  const AdminWorkoutRepositoryImpl(this._remote);

  final AdminWorkoutRemoteDataSource _remote;

  @override
  Future<List<AdminWorkout>> getWorkouts() => _run(_remote.fetchWorkouts);

  @override
  Future<void> deleteWorkout(int workoutId) => _run(() => _remote.deleteWorkout(workoutId));

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      throw ServerFailure(e.message);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
