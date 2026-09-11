import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/video.dart';
import '../../domain/usecases/get_video.dart';
import '../../domain/usecases/upload_video.dart';
import '../../domain/usecases/validate_video_file.dart';

/// ChangeNotifier backing `UploadVideoScreen` — owns the picked file,
/// upload state, and delegates the actual format/size rules and network
/// call to the domain use cases instead of the widget.
///
/// Analysis runs server-side in the background AFTER `upload()` returns
/// (see `Video`'s doc comment), so this also polls `GET /videos/{id}`
/// (via [GetVideo]) until [analyzedVideo] is ready or polling gives up.
class VideoUploadController extends ChangeNotifier {
  VideoUploadController({
    required UploadVideo uploadVideo,
    required GetVideo getVideo,
    required ValidateVideoFile validateVideoFile,
  })  : _uploadVideo = uploadVideo,
        _getVideo = getVideo,
        _validateVideoFile = validateVideoFile;

  final UploadVideo _uploadVideo;
  final GetVideo _getVideo;
  final ValidateVideoFile _validateVideoFile;

  static const _pollInterval = Duration(seconds: 3);
  // ~400 sampled frames at most per video (see video_analysis_service.py) —
  // 20 attempts * 3s = 60s covers the typical case with margin without
  // polling forever on a stuck/very long job.
  static const _maxPollAttempts = 20;

  File? selectedFile;
  bool isUploading = false;
  String? errorMessage;
  bool uploadSucceeded = false;

  /// Non-null once the background analysis job has written a result back
  /// (see [Video]'s doc comment — `analysisSummary` is ALWAYS set once the
  /// job finishes, even for an unsupported exercise or unreadable file).
  Video? analyzedVideo;
  bool isAnalyzing = false;
  /// True if polling gave up before the job finished — analysis is likely
  /// still running server-side, just slower than [_maxPollAttempts] covers.
  bool analysisTimedOut = false;

  Timer? _pollTimer;
  int _pollAttempts = 0;

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
    _resetAnalysisState();
    notifyListeners();
    return true;
  }

  Future<void> upload({required String exercise}) async {
    final file = selectedFile;
    if (file == null) return;

    isUploading = true;
    errorMessage = null;
    _resetAnalysisState();
    notifyListeners();

    try {
      final video = await _uploadVideo(file: file, exercise: exercise);
      uploadSucceeded = true;
      selectedFile = null;
      _startPolling(video.id);
    } on AppFailure catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not reach the server. Check your connection.';
    } finally {
      isUploading = false;
      notifyListeners();
    }
  }

  void _resetAnalysisState() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollAttempts = 0;
    analyzedVideo = null;
    isAnalyzing = false;
    analysisTimedOut = false;
  }

  void _startPolling(int videoId) {
    isAnalyzing = true;
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll(videoId));
  }

  Future<void> _poll(int videoId) async {
    _pollAttempts++;
    try {
      final video = await _getVideo(videoId);
      if (video.analysisSummary != null) {
        analyzedVideo = video;
        isAnalyzing = false;
        _pollTimer?.cancel();
        notifyListeners();
        return;
      }
    } catch (_) {
      // Transient network hiccup — just try again next tick rather than
      // surfacing an error for something the user didn't directly trigger.
    }
    if (_pollAttempts >= _maxPollAttempts) {
      isAnalyzing = false;
      analysisTimedOut = true;
      _pollTimer?.cancel();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
