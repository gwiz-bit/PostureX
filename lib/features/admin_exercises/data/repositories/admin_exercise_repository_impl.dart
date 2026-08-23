import 'dart:io';

import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/admin_exercise.dart';
import '../../domain/repositories/admin_exercise_repository.dart';
import '../datasources/admin_exercise_remote_data_source.dart';

class AdminExerciseRepositoryImpl implements AdminExerciseRepository {
  const AdminExerciseRepositoryImpl(this._remote);

  final AdminExerciseRemoteDataSource _remote;

  @override
  Future<List<AdminExercise>> getExercises() => _run(_remote.fetchExercises);

  @override
  Future<AdminExercise> createExercise({
    required String name,
    String? description,
    String? category,
    String? difficulty,
    String exerciseType = 'Standard',
  }) {
    return _run(() => _remote.createExercise(
          name: name,
          description: description,
          category: category,
          difficulty: difficulty,
          exerciseType: exerciseType,
        ));
  }

  @override
  Future<AdminExercise> updateExercise(int exerciseId, {bool? isActive}) {
    return _run(() => _remote.updateExercise(exerciseId, isActive: isActive));
  }

  @override
  Future<void> deleteExercise(int exerciseId) => _run(() => _remote.deleteExercise(exerciseId));

  @override
  Future<AdminExercise> uploadExerciseVideo({required int exerciseId, required File file}) {
    return _run(() => _remote.uploadExerciseVideo(exerciseId: exerciseId, file: file));
  }

  @override
  Future<AdminExercise> deleteExerciseVideo(int exerciseId) {
    return _run(() => _remote.deleteExerciseVideo(exerciseId));
  }

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
