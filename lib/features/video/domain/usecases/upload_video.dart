import 'dart:io';

import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Uploads a workout video. The backend never runs analysis on it
/// (duration/reps/accuracy come back null/0) — callers should not
/// synthesize a workout history entry from the result.
class UploadVideo {
  const UploadVideo(this._repository);

  final VideoRepository _repository;

  Future<Video> call({required File file, required String exercise}) {
    return _repository.uploadVideo(file: file, exercise: exercise);
  }
}
