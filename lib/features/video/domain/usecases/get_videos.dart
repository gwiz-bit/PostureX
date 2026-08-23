import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Fetches the current user's uploaded videos.
class GetVideos {
  const GetVideos(this._repository);

  final VideoRepository _repository;

  Future<List<Video>> call() => _repository.getVideos();
}
