import '../../../../services/api_client.dart';
import '../../domain/entities/admin_video.dart';

class AdminVideoRemoteDataSource {
  const AdminVideoRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<AdminVideo>> fetchVideos() => _client.fetchAdminVideos();

  Future<void> deleteVideo(int videoId) => _client.deleteAdminVideo(videoId);
}
