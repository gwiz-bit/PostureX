import '../repositories/admin_video_repository.dart';

class DeleteAdminVideo {
  const DeleteAdminVideo(this._repository);

  final AdminVideoRepository _repository;

  Future<void> call(int videoId) => _repository.deleteVideo(videoId);
}
