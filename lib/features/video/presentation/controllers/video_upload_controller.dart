import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/usecases/upload_video.dart';
import '../../domain/usecases/validate_video_file.dart';

/// ChangeNotifier backing `UploadVideoScreen` — owns the picked file,
/// upload state, and delegates the actual format/size rules and network
/// call to the domain use cases instead of the widget.
class VideoUploadController extends ChangeNotifier {
  VideoUploadController({
    required UploadVideo uploadVideo,
    required ValidateVideoFile validateVideoFile,
  })  : _uploadVideo = uploadVideo,
        _validateVideoFile = validateVideoFile;

  final UploadVideo _uploadVideo;
  final ValidateVideoFile _validateVideoFile;

  File? selectedFile;
  bool isUploading = false;
  String? errorMessage;
  bool uploadSucceeded = false;

  /// Validates and stages [file] for upload. Returns `true` if accepted.
  bool selectFile(File file, int sizeBytes) {
    final error = _validateVideoFile(path: file.path, sizeBytes: sizeBytes);
    if (error != null) {
      selectedFile = null;
      errorMessage = error;
      notifyListeners();
      return false;
    }
    selectedFile = file;
    errorMessage = null;
    uploadSucceeded = false;
    notifyListeners();
    return true;
  }

  Future<void> upload({required String exercise}) async {
    final file = selectedFile;
    if (file == null) return;

    isUploading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _uploadVideo(file: file, exercise: exercise);
      uploadSucceeded = true;
      selectedFile = null;
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }
}
