import '../entities/admin_workout.dart';

abstract class AdminWorkoutRepository {
  Future<List<AdminWorkout>> getWorkouts();

  Future<void> deleteWorkout(int workoutId);
}
