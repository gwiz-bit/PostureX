import 'dart:io';

import '../entities/admin_exercise.dart';
import '../repositories/admin_exercise_repository.dart';

class UploadAdminExerciseVideo {
  const UploadAdminExerciseVideo(this._repository);

  final AdminExerciseRepository _repository;

  Future<AdminExercise> call({required int exerciseId, required File file}) {
    return _repository.uploadExerciseVideo(exerciseId: exerciseId, file: file);
  }
}
