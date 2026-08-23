import 'dart:io';

import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/video.dart';
import '../../domain/repositories/video_repository.dart';
import '../datasources/video_remote_data_source.dart';

class VideoRepositoryImpl implements VideoRepository {
  const VideoRepositoryImpl(this._remote);

  final VideoRemoteDataSource _remote;

  @override
  Future<Video> uploadVideo({required File file, required String exercise}) =>
      _run(() => _remote.uploadVideo(file: file, exercise: exercise));

  @override
  Future<List<Video>> getVideos() => _run(_remote.fetchVideos);

  @override
  Future<Video> getVideo(int id) => _run(() => _remote.fetchVideo(id));

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
