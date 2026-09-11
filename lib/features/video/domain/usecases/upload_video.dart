import 'dart:io';

import '../entities/video.dart';
import '../repositories/video_repository.dart';

/// Uploads a workout video for the given [exercise] (must be the exact
/// exercise name — the backend picks the analyzer by matching it against
/// `ANALYZER_REGISTRY`, and a wrong/generic name silently analyzes the
/// footage as the wrong exercise). Analysis runs in the background after
/// this call returns — see [Video]'s doc comment for how to poll for it.
class UploadVideo {
  const UploadVideo(this._repository);

  final VideoRepository _repository;

  Future<Video> call({required File file, required String exercise}) {
    return _repository.uploadVideo(file: file, exercise: exercise);
  }
}
