import '../../../../utils/workout_stats.dart';
import '../entities/workout.dart';

/// Pure aggregation over an already-fetched workout list — no I/O. Wraps
/// the existing `computeStats()` helper (shared with the old Home/Profile
/// screens) instead of re-implementing the averaging logic.
class GetWorkoutStats {
  const GetWorkoutStats();

  WorkoutStats call(List<Workout> workouts) => computeStats(workouts);
}
