import 'dart:io';

import '../entities/video.dart';

abstract class VideoRepository {
  Future<Video> uploadVideo({required File file, required String exercise});

  Future<List<Video>> getVideos();

  Future<Video> getVideo(int id);
}
