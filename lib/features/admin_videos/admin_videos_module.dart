import '../../services/api_client.dart';
import 'data/datasources/admin_video_remote_data_source.dart';
import 'data/repositories/admin_video_repository_impl.dart';
import 'domain/repositories/admin_video_repository.dart';
import 'domain/usecases/delete_admin_video.dart';
import 'domain/usecases/get_admin_videos.dart';

class AdminVideosModule {
  AdminVideosModule._();

  static AdminVideoRepository _repository() =>
      AdminVideoRepositoryImpl(AdminVideoRemoteDataSource(ApiClient.instance));

  static GetAdminVideos getAdminVideos() => GetAdminVideos(_repository());

  static DeleteAdminVideo deleteAdminVideo() => DeleteAdminVideo(_repository());
}
