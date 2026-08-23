import '../entities/admin_video.dart';
import '../repositories/admin_video_repository.dart';

class GetAdminVideos {
  const GetAdminVideos(this._repository);

  final AdminVideoRepository _repository;

  Future<List<AdminVideo>> call() => _repository.getVideos();
}
