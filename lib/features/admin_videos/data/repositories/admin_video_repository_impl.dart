import '../../../../core/errors/failures.dart';
import '../../../../services/api_exception.dart';
import '../../domain/entities/admin_video.dart';
import '../../domain/repositories/admin_video_repository.dart';
import '../datasources/admin_video_remote_data_source.dart';

class AdminVideoRepositoryImpl implements AdminVideoRepository {
  const AdminVideoRepositoryImpl(this._remote);

  final AdminVideoRemoteDataSource _remote;

  @override
  Future<List<AdminVideo>> getVideos() => _run(_remote.fetchVideos);

  @override
  Future<void> deleteVideo(int videoId) => _run(() => _remote.deleteVideo(videoId));

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
