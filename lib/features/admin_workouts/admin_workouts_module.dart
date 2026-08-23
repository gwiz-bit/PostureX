import '../../services/api_client.dart';
import 'data/datasources/admin_workout_remote_data_source.dart';
import 'data/repositories/admin_workout_repository_impl.dart';
import 'domain/repositories/admin_workout_repository.dart';
import 'domain/usecases/delete_admin_workout.dart';
import 'domain/usecases/get_admin_workouts.dart';

class AdminWorkoutsModule {
  AdminWorkoutsModule._();

  static AdminWorkoutRepository _repository() =>
      AdminWorkoutRepositoryImpl(AdminWorkoutRemoteDataSource(ApiClient.instance));

  static GetAdminWorkouts getAdminWorkouts() => GetAdminWorkouts(_repository());

  static DeleteAdminWorkout deleteAdminWorkout() => DeleteAdminWorkout(_repository());
}
