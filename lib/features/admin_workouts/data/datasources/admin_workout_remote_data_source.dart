import '../../../../services/api_client.dart';
import '../../domain/entities/admin_workout.dart';

class AdminWorkoutRemoteDataSource {
  const AdminWorkoutRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AdminWorkout>> fetchWorkouts() => _client.fetchAdminWorkouts();

  Future<void> deleteWorkout(int workoutId) => _client.deleteAdminWorkout(workoutId);
}
