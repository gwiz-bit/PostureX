import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/features/workout/domain/entities/workout.dart';
import 'package:posturex/features/workout/domain/usecases/get_workout_stats.dart';

Workout _workout({int totalReps = 10, double? accuracyScore}) {
  final now = DateTime(2026, 1, 1);
  return Workout(
    id: 1,
    exercise: 'squat',
    totalReps: totalReps,
    durationSeconds: 60,
    accuracyScore: accuracyScore,
    startedAt: now,
    endedAt: now,
    createdAt: now,
  );
}

void main() {
  // Pure unit tests — no MockClient, no SecureStorageBackend, no widget
  // pump. This is exactly the payoff the migration plan called out: domain
  // logic tested in isolation from the Flutter/network layers.
  group('GetWorkoutStats', () {
    const usecase = GetWorkoutStats();

    test('returns zeroed stats for an empty history', () {
      final stats = usecase(const []);

      expect(stats.sessionCount, 0);
      expect(stats.totalReps, 0);
      expect(stats.averageAccuracy, isNull);
      expect(stats.bestAccuracy, isNull);
    });

    test('averages only workouts that have an accuracy score', () {
      final workouts = [
        _workout(totalReps: 10, accuracyScore: 80),
        _workout(totalReps: 8, accuracyScore: null), // e.g. an in-progress upload
        _workout(totalReps: 12, accuracyScore: 90),
      ];

      final stats = usecase(workouts);

      expect(stats.sessionCount, 3);
      expect(stats.totalReps, 30);
      expect(stats.averageAccuracy, 85);
      expect(stats.bestAccuracy, 90);
    });
  });
}
