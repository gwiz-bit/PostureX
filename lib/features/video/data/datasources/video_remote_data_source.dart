import 'dart:io';

import '../../../../services/api_client.dart';
import '../../domain/entities/video.dart';

/// Thin wrapper around [ApiClient]'s video endpoints — the only place in
/// the video feature allowed to know the REST layer exists.
class VideoRemoteDataSource {
  const VideoRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Video> uploadVideo({required File file, required String exercise}) =>
      _client.uploadVideo(file: file, exercise: exercise);

  Future<List<Video>> fetchVideos() => _client.fetchVideos();

  Future<Video> fetchVideo(int id) => _client.fetchVideo(id);
}
