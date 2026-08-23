import '../entities/admin_video.dart';

abstract class AdminVideoRepository {
  Future<List<AdminVideo>> getVideos();

  Future<void> deleteVideo(int videoId);
}
