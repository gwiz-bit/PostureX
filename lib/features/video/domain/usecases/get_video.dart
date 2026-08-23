import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Fetches a single video by id.
class GetVideo {
  const GetVideo(this._repository);

  final VideoRepository _repository;

  Future<Video> call(int id) => _repository.getVideo(id);
}
