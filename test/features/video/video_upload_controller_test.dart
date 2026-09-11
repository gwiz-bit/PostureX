import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posturex/features/video/domain/entities/video.dart';
import 'package:posturex/features/video/domain/repositories/video_repository.dart';
import 'package:posturex/features/video/domain/usecases/get_video.dart';
import 'package:posturex/features/video/domain/usecases/upload_video.dart';
import 'package:posturex/features/video/domain/usecases/validate_video_file.dart';
import 'package:posturex/features/video/presentation/controllers/video_upload_controller.dart';

/// Fakes the network-facing repository so these tests exercise the
/// controller's own logic (upload -> poll -> ready/timeout state machine)
/// without a real backend — same spirit as `api_client_timeout_test.dart`'s
/// `MockClient`, one layer up.
class _FakeVideoRepository implements VideoRepository {
  _FakeVideoRepository({required this.uploadedId, this.summariesByAttempt = const []});

  final int uploadedId;
  /// `analysisSummary` returned on the Nth call to `getVideo` (1-indexed);
  /// `null` entries simulate "still analyzing". Calls past the list length
  /// keep returning the last entry (or null if the list is empty).
  final List<String?> summariesByAttempt;

  int getVideoCallCount = 0;

  Video _video({String? analysisSummary}) => Video(
        id: uploadedId,
        userId: 1,
        exercise: 'squat',
        originalFilename: 'clip.mp4',
        durationSeconds: null,
        totalReps: analysisSummary == null ? 0 : 8,
        accuracyScore: analysisSummary == null ? null : 92.0,
        analysisSummary: analysisSummary,
        createdAt: DateTime(2026, 9, 11),
      );

  @override
  Future<Video> uploadVideo({required File file, required String exercise}) async =>
      _video();

  @override
  Future<List<Video>> getVideos() async => [];

  @override
  Future<Video> getVideo(int id) async {
    getVideoCallCount++;
    final summary = getVideoCallCount <= summariesByAttempt.length
        ? summariesByAttempt[getVideoCallCount - 1]
        : (summariesByAttempt.isEmpty ? null : summariesByAttempt.last);
    return _video(analysisSummary: summary);
  }
}

VideoUploadController _controllerWith(_FakeVideoRepository repo) => VideoUploadController(
      uploadVideo: UploadVideo(repo),
      getVideo: GetVideo(repo),
      validateVideoFile: const ValidateVideoFile(),
    );

void main() {
  final validFile = File('clip.mp4');

  test('polls until analysisSummary is ready, then exposes the result', () {
    fakeAsync((async) {
      final repo = _FakeVideoRepository(
        uploadedId: 42,
        summariesByAttempt: [null, null, 'Tốt lắm, 8 rep đúng kỹ thuật.'],
      );
      final controller = _controllerWith(repo);
      controller.selectFile(validFile, 1024);

      unawaited(controller.upload(exercise: 'squat'));
      async.elapse(const Duration(milliseconds: 1)); // let the upload future settle

      expect(controller.uploadSucceeded, isTrue);
      expect(controller.isAnalyzing, isTrue);
      expect(controller.analyzedVideo, isNull);

      async.elapse(const Duration(seconds: 3)); // 1st poll -> still null
      expect(controller.isAnalyzing, isTrue);
      expect(controller.analyzedVideo, isNull);

      async.elapse(const Duration(seconds: 3)); // 2nd poll -> still null
      expect(controller.isAnalyzing, isTrue);

      async.elapse(const Duration(seconds: 3)); // 3rd poll -> ready
      expect(controller.isAnalyzing, isFalse);
      expect(controller.analysisTimedOut, isFalse);
      expect(controller.analyzedVideo?.analysisSummary, 'Tốt lắm, 8 rep đúng kỹ thuật.');
      expect(controller.analyzedVideo?.totalReps, 8);
      expect(controller.analyzedVideo?.accuracyScore, 92.0);

      // Polling must have actually stopped — no more calls past the 3rd.
      async.elapse(const Duration(seconds: 30));
      expect(repo.getVideoCallCount, 3);
    });
  });

  test('gives up after the max polling window if analysis never finishes', () {
    fakeAsync((async) {
      final repo = _FakeVideoRepository(uploadedId: 1); // always null summary
      final controller = _controllerWith(repo);
      controller.selectFile(validFile, 1024);

      unawaited(controller.upload(exercise: 'squat'));
      async.elapse(const Duration(milliseconds: 1));

      // 20 attempts * 3s — see VideoUploadController._maxPollAttempts.
      async.elapse(const Duration(seconds: 60));

      expect(controller.isAnalyzing, isFalse);
      expect(controller.analysisTimedOut, isTrue);
      expect(controller.analyzedVideo, isNull);

      // Must not keep polling forever past the give-up point.
      final callsAtTimeout = repo.getVideoCallCount;
      async.elapse(const Duration(seconds: 30));
      expect(repo.getVideoCallCount, callsAtTimeout);
    });
  });

  test('selecting a new file clears the previous analysis result', () {
    fakeAsync((async) {
      final repo = _FakeVideoRepository(uploadedId: 1, summariesByAttempt: ['Done.']);
      final controller = _controllerWith(repo);
      controller.selectFile(validFile, 1024);
      unawaited(controller.upload(exercise: 'squat'));
      async.elapse(const Duration(milliseconds: 1));
      async.elapse(const Duration(seconds: 3));
      expect(controller.analyzedVideo, isNotNull);

      controller.selectFile(validFile, 2048);

      expect(controller.analyzedVideo, isNull);
      expect(controller.isAnalyzing, isFalse);

      // A stray tick from the old (cancelled) timer must not resurrect it.
      async.elapse(const Duration(seconds: 10));
      expect(controller.analyzedVideo, isNull);
    });
  });
}
