import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../utils/workout_stats.dart';
import '../../domain/entities/workout.dart';
import '../../domain/usecases/create_workout.dart';
import '../../domain/usecases/get_workout_stats.dart';
import '../../domain/usecases/get_workouts.dart';

/// ChangeNotifier for the Workout feature — screens listen to this instead
/// of calling `ApiClient`/use cases directly, so a `notifyListeners()` here
/// is the one place that decides when the UI should redraw.
class WorkoutController extends ChangeNotifier {
  WorkoutController({
    required GetWorkouts getWorkouts,
    required CreateWorkout createWorkout,
    required GetWorkoutStats getWorkoutStats,
  })  : _getWorkouts = getWorkouts,
        _createWorkout = createWorkout,
        _getWorkoutStats = getWorkoutStats;

  final GetWorkouts _getWorkouts;
  final CreateWorkout _createWorkout;
  final GetWorkoutStats _getWorkoutStats;

  bool isLoading = false;
  String? errorMessage;
  List<Workout> workouts = const [];
  WorkoutStats stats = const WorkoutStats(
    sessionCount: 0,
    totalReps: 0,
    averageAccuracy: null,
    bestAccuracy: null,
  );

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      workouts = await _getWorkouts();
      stats = _getWorkoutStats(workouts);
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not load your workout history.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Logs a completed session and returns a user-facing error message on
  /// failure (or `null` on success) — callers show it inline themselves
  /// rather than reading error state back off this controller, since the
  /// caller (e.g. `AnalyzeSessionScreen`) usually isn't the screen that
  /// owns this controller instance.
  Future<String?> createWorkout({
    required String exercise,
    int totalReps = 0,
    double? durationSeconds,
    double? accuracyScore,
    required DateTime startedAt,
  }) async {
    try {
      await _createWorkout(
        exercise: exercise,
        totalReps: totalReps,
        durationSeconds: durationSeconds,
        accuracyScore: accuracyScore,
        startedAt: startedAt,
      );
      return null;
    } on AppFailure catch (e) {
      return e.message;
    } catch (_) {
      return 'Không lưu được buổi tập. Kiểm tra kết nối mạng.';
    }
  }
}
