import 'dart:io';

import '../../../../services/api_client.dart';
import '../../domain/entities/admin_exercise.dart';

class AdminExerciseRemoteDataSource {
  const AdminExerciseRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AdminExercise>> fetchExercises() => _client.fetchAdminExercises();

  Future<AdminExercise> createExercise({
    required String name,
    String? description,
    String? category,
    String? difficulty,
    String exerciseType = 'Standard',
  }) {
    return _client.createAdminExercise(
      name: name,
      description: description,
      category: category,
      difficulty: difficulty,
      exerciseType: exerciseType,
    );
  }

  Future<AdminExercise> updateExercise(int exerciseId, {bool? isActive}) {
    return _client.updateAdminExercise(exerciseId, isActive: isActive);
  }

  Future<void> deleteExercise(int exerciseId) => _client.deleteAdminExercise(exerciseId);

  Future<AdminExercise> uploadExerciseVideo({required int exerciseId, required File file}) {
    return _client.uploadAdminExerciseVideo(exerciseId: exerciseId, file: file);
  }

  Future<AdminExercise> deleteExerciseVideo(int exerciseId) =>
      _client.deleteAdminExerciseVideo(exerciseId);
}
