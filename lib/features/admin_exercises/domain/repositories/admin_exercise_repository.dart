import 'dart:io';

import '../entities/admin_exercise.dart';

abstract class AdminExerciseRepository {
  Future<List<AdminExercise>> getExercises();

  Future<AdminExercise> createExercise({
    required String name,
    String? description,
    String? category,
    String? difficulty,
    String exerciseType = 'Standard',
  });

  Future<AdminExercise> updateExercise(int exerciseId, {bool? isActive});

  Future<void> deleteExercise(int exerciseId);

  Future<AdminExercise> uploadExerciseVideo({required int exerciseId, required File file});

  Future<AdminExercise> deleteExerciseVideo(int exerciseId);
}
