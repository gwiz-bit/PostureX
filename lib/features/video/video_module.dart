import '../../services/api_client.dart';
import 'data/datasources/video_remote_data_source.dart';
import 'data/repositories/video_repository_impl.dart';
import 'domain/repositories/video_repository.dart';
import 'domain/usecases/get_video.dart';
import 'domain/usecases/get_videos.dart';
import 'domain/usecases/upload_video.dart';
import 'domain/usecases/validate_video_file.dart';
import 'presentation/controllers/video_upload_controller.dart';

/// Manual composition root for the Video feature — same pattern as
/// `WorkoutModule`, no DI framework.
class VideoModule {
  VideoModule._();

  static VideoRepository _repository() =>
      VideoRepositoryImpl(VideoRemoteDataSource(ApiClient.instance));

  static UploadVideo uploadVideo() => UploadVideo(_repository());

  static GetVideos getVideos() => GetVideos(_repository());

  static GetVideo getVideo() => GetVideo(_repository());

  static const ValidateVideoFile validateVideoFile = ValidateVideoFile();

  static VideoUploadController uploadController() => VideoUploadController(
        uploadVideo: uploadVideo(),
        validateVideoFile: validateVideoFile,
      );
}
