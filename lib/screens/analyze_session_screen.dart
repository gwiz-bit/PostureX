import 'dart:async';
import 'dart:math' show pi;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../config/api_config.dart';
import '../core/errors/failures.dart';
import '../features/exercises/exercises_module.dart';
import '../features/workout/workout_module.dart';
import '../models/frame_analysis_result.dart';
import '../services/analyze_socket_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_locale.dart';
import '../utils/exercise_videos.dart';
import '../utils/squat_error_tips.dart';
import '../widgets/guide_video_player.dart';
import '../widgets/skeleton_painter.dart';
import 'workout_summary_screen.dart';

enum _SessionStatus {
  initializing,
  permissionDenied,
  connecting,
  running,
  error,
}

const _noPersonMessage = 'Không phát hiện được người trong frame.';
const _frameInterval = Duration(milliseconds: 80); // ~12 fps cap

/// How many consecutive frames the same mistake category must appear in
/// before it gets read aloud via TTS. At the ~9fps frame cap this is under
/// half a second — short, but matches "lặp lại 3 lần liên tiếp" literally;
/// tune here if that turns out to fire too eagerly in practice.
const _ttsRepeatThreshold = 3;

/// Full-screen camera capture that streams frames to the backend's
/// `/api/v1/ws/analyze` WebSocket and renders live rep-count/phase/error
/// feedback for [exercise].
///
/// The backend maps ~106 exercise names to 9 analyzer classes
/// (`ANALYZER_REGISTRY` in `app/ml/analyzers/registry.py`) — every entry
/// point here (`WorkoutScreen`, `ExerciseDetailScreen`, `HomeScreen`) passes
/// through the specific exercise's own identifier, not a hardcoded value.
/// Exercises sharing an analyzer family (e.g. 21 different squat variants
/// all use `SquatAnalyzer`) do get genuinely identical feedback unless that
/// exercise has its own row in `ExercisePostureRules` — that's a threshold
/// coverage gap (see `CLAUDE.md`), not a routing bug.
class AnalyzeSessionScreen extends StatefulWidget {
  const AnalyzeSessionScreen({
    super.key,
    required this.exercise,
    this.routineName,
  });

  final String exercise;
  final String? routineName;

  @override
  State<AnalyzeSessionScreen> createState() => _AnalyzeSessionScreenState();
}

/// How many degrees to rotate a raw sensor frame so it comes out upright,
/// for a device held in natural (locked) portrait orientation.
///
/// Just use `sensorOrientation` directly — for BOTH cameras. This is the
/// standard Android rotation-compensation formula (as used in Google's own
/// reference `camera_view.dart` from `google_ml_kit_flutter`, and in the
/// wider Android Camera2 ecosystem): the general formula is
/// `(sensorOrientation + deviceOrientationDegrees) % 360` for the front
/// camera and `(sensorOrientation - deviceOrientationDegrees + 360) % 360`
/// for the back camera, where `deviceOrientationDegrees` compensates for the
/// device being rotated away from its natural orientation. For a device
/// locked to natural portrait (this app's only supported orientation),
/// `deviceOrientationDegrees` is 0, so BOTH formulas collapse to plain
/// `sensorOrientation` — no complement, no negation.
///
/// A previous version of this function used `(360 - sensorOrientation) % 360`
/// for the front camera specifically, reasoning that the front sensor's
/// physical mounting needed a "complement" correction. That reasoning
/// conflated two orthogonal concerns: rotation (this function) and
/// left/right mirroring (a separate concern, now handled entirely by the
/// `Transform`/`Matrix4.rotationY` wrapping the camera+skeleton stack in
/// `build()` — see that code and its own history for why mirroring must
/// never be smuggled into a rotation angle). The complement formula happened
/// to produce a value that looked plausible (90° for both cameras, given the
/// common 90°/270° sensorOrientation split on most phones) but was off by
/// 180° for the front camera specifically — confirmed via a real bug report
/// (14/09/2026, see CHANGELOG) where front-camera face keypoints consistently
/// rendered near the WAIST instead of near the head, exactly the symptom of
/// a 180°-rotated frame being sent to the backend for pose detection.
int rotationDegreesFor(CameraDescription camera) => camera.sensorOrientation;

class _AnalyzeSessionScreenState extends State<AnalyzeSessionScreen>
    with WidgetsBindingObserver, AppLocaleMixin {
  final _socket = AnalyzeSocketService();
  StreamSubscription<AnalyzeSocketEvent>? _socketSub;
  CameraController? _controller;
  int _rotationDegrees = 0;

  _SessionStatus _status = _SessionStatus.initializing;
  String? _statusMessage;

  int _repCount = 0;
  String _phase = 'going_down';
  bool _correct = true;
  List<String> _errors = const [];
  Map<String, Point>? _keypoints;
  final List<bool> _correctnessSamples = [];

  /// Raw joint angles from the most recent frame — shown in a small debug
  /// overlay (see [_buildDebugAngleOverlay]) so a tester can read back exact
  /// numbers ("tôi kéo tới 95° là hết cỡ") instead of only describing the
  /// symptom in words. Added 15/09/2026: every threshold bug found so far
  /// (calf raise, pulldown) needed a script simulation to pin down because
  /// no one could report the actual angle reached during a failed rep —
  /// this puts that number on screen directly, no simulation needed to
  /// interpret the next report.
  KeyAngles? _keyAngles;

  /// "Độ giống bài mẫu" (0-100) của frame gần nhất — `null` khi bài chưa có
  /// chuẩn tham chiếu hoặc cửa sổ live chưa đủ dữ liệu để tính (xem
  /// [FrameAnalysisResult.similarityScore]); `null` ẩn hẳn thanh điểm thay
  /// vì hiện 0% (0% sẽ đọc nhầm thành "tập sai hoàn toàn").
  double? _similarityScore;

  CameraLensDirection _lensDirection = CameraLensDirection.front;
  bool _isFlipping = false;

  bool _awaitingResponse = false;
  Timer? _responseTimeoutTimer;
  DateTime? _lastFrameSentAt;
  DateTime? _sessionStart;

  /// Round-trip diagnostics (send → response), logged every
  /// [_latencyLogBatchSize] frames instead of per-frame to avoid flooding
  /// `flutter logs` — added 15/09/2026 after a report of "lag" with no
  /// concrete numbers to act on. Simulating `RepCounter` directly showed it
  /// tolerates sparse sampling fine as long as the true angle is reached
  /// (see `pulldown.py` CHANGELOG entry same day, the actual rep-counting
  /// bug found that day was a threshold too strict, not this) — so this
  /// exists to answer a DIFFERENT, still-open question: how slow is the
  /// round trip in practice, and how often does the 500ms safety-net timeout
  /// below actually fire (a fired timeout means a frame's response was
  /// discarded, not just slow). Both matter for the "feels laggy" complaint
  /// even where they don't explain missed reps.
  static const _latencyLogBatchSize = 30;
  int _latencySampleCount = 0;
  int _latencyTotalMs = 0;
  int _latencyMaxMs = 0;
  int _timeoutDropCount = 0;
  bool _isEnding = false;
  bool _isPaused = false;
  String? _transientError;
  Timer? _transientErrorTimer;

  /// Admin-uploaded guide video for [widget.exercise], if one exists —
  /// `null` until fetched (falls back to the bundled asset via
  /// [guideVideoAssetFor] either while loading or if none was uploaded).
  String? _guideVideoUrl;

  final _tts = FlutterTts();

  /// Tallied by mistake category (see [categorizeSquatError]), not raw
  /// message, so the live angle value some messages embed doesn't
  /// fragment one recurring mistake into many near-duplicate entries —
  /// carried into [WorkoutSummaryScreen] when the session ends.
  final Map<String, int> _errorCounts = {};
  /// Categories present in the previous frame — used so [_errorCounts]
  /// increments once per mistake *episode* (rising edge) instead of once
  /// per analyzed frame. At the ~9fps frame cap a mistake held for one
  /// whole rep would otherwise inflate to 15-20+ counts for what was
  /// really a single continuous mistake.
  final Set<String> _activeErrorCategories = {};
  String? _lastErrorCategory;
  int _consecutiveErrorCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.setLanguage('vi-VN');
    _init();
    _loadGuideVideo();
  }

  /// Best-effort, independent of [_init]'s camera/socket setup — a failed
  /// fetch here should never block the analyze session, just leave the
  /// panel on the bundled asset fallback.
  Future<void> _loadGuideVideo() async {
    try {
      final exercises = await ExercisesModule.getExercises()();
      final match = exercises.where(
        (e) => e.name.toLowerCase() == widget.exercise.toLowerCase(),
      );
      final url = match.isEmpty ? null : match.first.demoVideoUrl;
      if (mounted && url != null) {
        setState(() => _guideVideoUrl = '${ApiConfig.baseUrl}$url');
      }
    } catch (_) {
      // Keep the bundled asset fallback.
    }
  }

  Future<void> _init() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) setState(() => _status = _SessionStatus.permissionDenied);
      return;
    }

    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      _rotationDegrees = rotationDegreesFor(camera);

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() => _status = _SessionStatus.connecting);

      await _socket.connect(widget.exercise);
      _socketSub = _socket.events.listen(_onSocketEvent);
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _SessionStatus.error;
          _statusMessage = AppLocale.t('analyze_init_error');
        });
      }
    }
  }

  Future<void> _reinitializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == _lensDirection,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      if (_status == _SessionStatus.running) {
        await controller.startImageStream(_onCameraFrame);
      }
      setState(() {});
    } catch (_) {
      // Best-effort resume — leave the user on whatever state they were in.
    }
  }

  Future<void> _flipCamera() async {
    if (_isFlipping) return;
    final newDirection = _lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    // Check BEFORE touching the controller — emulators often only have one
    // camera. If the target direction doesn't exist, do nothing so there's
    // no black flash and no disruption to the running session.
    final cameras = await availableCameras();
    final matching = cameras.where((c) => c.lensDirection == newDirection);
    if (matching.isEmpty) return;
    final targetCamera = matching.first;

    final oldController = _controller;
    final wasStreaming = _status == _SessionStatus.running && !_isPaused;
    // Null out _controller before the async dispose so any rebuild triggered
    // during the await shows the spinner instead of crashing on CameraPreview
    // with an already-disposed controller.
    setState(() {
      _isFlipping = true;
      _controller = null;
    });
    try {
      if (oldController?.value.isStreamingImages ?? false) {
        await oldController!.stopImageStream();
      }
      await oldController?.dispose();

      final controller = CameraController(
        targetCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _lensDirection = newDirection;
        _rotationDegrees = rotationDegreesFor(targetCamera);
        _isFlipping = false;
      });
      if (wasStreaming) {
        await controller.startImageStream(_onCameraFrame);
      }
    } catch (_) {
      if (mounted) setState(() => _isFlipping = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _reinitializeCamera();
    }
  }

  void _onSocketEvent(AnalyzeSocketEvent event) {
    if (!mounted) return;

    if (event.readyMessage != null) {
      setState(() => _status = _SessionStatus.running);
      _sessionStart = DateTime.now();
      _controller?.startImageStream(_onCameraFrame);
      return;
    }

    if (event.frame != null) {
      final frame = event.frame!;
      _responseTimeoutTimer?.cancel();
      _awaitingResponse = false;
      _recordLatencySample();
      // "top" = đang đứng nghỉ/chưa vào tư thế (giữa các rep, hoặc trước khi
      // bắt đầu) — không tính vào độ chính xác, nếu không đứng yên trước
      // camera mà chưa tập gì cũng bị chấm gần 100% (không đúng động tác thì
      // cũng chẳng có gì để chấm sai). Chỉ tính khung hình khi analyzer báo
      // đang thực sự trong động tác (going_down/bottom/going_up, hoặc
      // "holding" với Plank).
      if (!frame.errors.contains(_noPersonMessage) && frame.phase != 'top') {
        _correctnessSamples.add(frame.correct);
      }
      if (frame.repCount > _repCount && frame.correct) {
        // Only beep for a rep that closed out clean — matches the spec's
        // "không tính rep nếu có lỗi nghiêm trọng" intent as closely as
        // possible without changing the backend's counting semantics
        // (every rep still counts toward the total either way).
        SystemSound.play(SystemSoundType.click);
      }
      _processErrorsForTts(frame.errors);
      setState(() {
        _repCount = frame.repCount;
        _phase = frame.phase;
        _correct = frame.correct;
        _errors = frame.errors;
        // allKeypoints (whole body) over keypoints (only what this exercise's
        // analyzer uses for angle math) — see SkeletonPainter's doc comment.
        // Falls back to keypoints only in case a stale build ever talks to a
        // backend that hasn't deployed all_keypoints yet.
        _keypoints = frame.allKeypoints ?? frame.keypoints;
        _similarityScore = frame.similarityScore;
        _keyAngles = frame.keyAngles;
      });
      return;
    }

    if (event.error != null) {
      _awaitingResponse = false;
      _showTransientError(event.error!);
    }
  }

  /// Tallies mistakes by category (for [WorkoutSummaryScreen]) and speaks
  /// the top one aloud once it's shown up in [_ttsRepeatThreshold]
  /// consecutive frames — "once" per streak, not every frame past the
  /// threshold, so it doesn't nag continuously while a mistake persists.
  void _processErrorsForTts(List<String> errors) {
    final categories = errors
        .map(categorizeSquatError)
        .whereType<String>()
        .toSet();
    for (final category in categories) {
      if (!_activeErrorCategories.contains(category)) {
        _errorCounts[category] = (_errorCounts[category] ?? 0) + 1;
      }
    }
    _activeErrorCategories
      ..clear()
      ..addAll(categories);

    final primaryCategory = categories.isEmpty ? null : categories.first;
    if (primaryCategory != null && primaryCategory == _lastErrorCategory) {
      _consecutiveErrorCount++;
    } else {
      _consecutiveErrorCount = primaryCategory == null ? 0 : 1;
    }
    _lastErrorCategory = primaryCategory;

    if (primaryCategory != null &&
        _consecutiveErrorCount == _ttsRepeatThreshold) {
      final tip = tipForCategory(primaryCategory);
      if (tip != null) _tts.speak(tip.label);
    }
  }

  void _showTransientError(String message) {
    _transientErrorTimer?.cancel();
    setState(() => _transientError = message);
    _transientErrorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _transientError = null);
    });
  }

  void _onCameraFrame(CameraImage image) {
    if (_status != _SessionStatus.running || _awaitingResponse || _isPaused)
      return;
    final now = DateTime.now();
    if (_lastFrameSentAt != null &&
        now.difference(_lastFrameSentAt!) < _frameInterval)
      return;
    _lastFrameSentAt = now;
    _awaitingResponse = true;
    // Safety net: if the server drops a response, _awaitingResponse would
    // stay true forever and block all future frames. Reset after 500 ms so
    // the next frame can be sent even if the current one was never answered.
    _responseTimeoutTimer?.cancel();
    _responseTimeoutTimer = Timer(const Duration(milliseconds: 500), () {
      _awaitingResponse = false;
      _timeoutDropCount++;
      debugPrint(
        '[analyze-latency] frame dropped: no response within 500ms '
        '(dropped $_timeoutDropCount so far this session)',
      );
    });
    _encodeAndSend(image);
  }

  /// Accumulates one round-trip sample (send → this response) and flushes a
  /// summary to `debugPrint` every [_latencyLogBatchSize] frames. See the
  /// field doc comment above for why this exists.
  void _recordLatencySample() {
    final sentAt = _lastFrameSentAt;
    if (sentAt == null) return;
    final elapsedMs = DateTime.now().difference(sentAt).inMilliseconds;
    _latencySampleCount++;
    _latencyTotalMs += elapsedMs;
    if (elapsedMs > _latencyMaxMs) _latencyMaxMs = elapsedMs;

    if (_latencySampleCount >= _latencyLogBatchSize) {
      final avgMs = _latencyTotalMs / _latencySampleCount;
      final effectiveFps = avgMs > 0 ? 1000 / avgMs : 0;
      debugPrint(
        '[analyze-latency] last $_latencySampleCount frames: '
        'avg ${avgMs.toStringAsFixed(0)}ms, max ${_latencyMaxMs}ms, '
        '~${effectiveFps.toStringAsFixed(1)} fps effective '
        '(dropped $_timeoutDropCount total this session)',
      );
      _latencySampleCount = 0;
      _latencyTotalMs = 0;
      _latencyMaxMs = 0;
    }
  }

  /// Small on-screen readout of the raw joint angles the backend is
  /// currently computing — see [_keyAngles] doc comment for why. Lists only
  /// the angles that are actually present for the active exercise (a squat
  /// session has no elbow angle, a curl session has no knee angle), each
  /// rounded to the nearest degree.
  Widget _buildDebugAngleOverlay() {
    final angles = _keyAngles;
    if (angles == null) return const SizedBox.shrink();
    final entries = <String, double?>{
      'L Vai': angles.leftShoulder,
      'P Vai': angles.rightShoulder,
      'L Khuỷu': angles.leftElbow,
      'P Khuỷu': angles.rightElbow,
      'L Hông': angles.leftHip,
      'P Hông': angles.rightHip,
      'L Gối': angles.leftKnee,
      'P Gối': angles.rightKnee,
      'L Cổ chân': angles.leftAnkle,
      'P Cổ chân': angles.rightAnkle,
      'Lưng': angles.backAngle,
    }..removeWhere((_, value) => value == null);
    if (entries.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 90,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: entries.entries
              .map(
                (e) => Text(
                  '${e.key}: ${e.value!.round()}°',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  Future<void> _encodeAndSend(CameraImage image) async {
    try {
      final jpeg = await compute(
        _encodeCameraImage,
        _EncodeArgs(image, _rotationDegrees),
      );
      _socket.sendFrame(jpeg);
    } catch (_) {
      _awaitingResponse = false;
    }
  }

  Future<void> _endSession() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
    await _socket.close();

    final startedAt = _sessionStart ?? DateTime.now();
    final durationSeconds = DateTime.now()
        .difference(startedAt)
        .inSeconds
        .toDouble();
    final accuracyScore = _correctnessSamples.isEmpty
        ? null
        : _correctnessSamples.where((c) => c).length /
              _correctnessSamples.length *
              100;

    // Buổi tập không lưu được thì phải nói ra. Backend chặn user gói Free sau
    // 3 buổi/ngày (403) — nuốt lỗi ở đây là để người dùng tin buổi tập đã lưu
    // trong khi lịch sử của họ trống.
    String? saveError;
    try {
      await WorkoutModule.createWorkout()(
        exercise: widget.exercise,
        totalReps: _repCount,
        durationSeconds: durationSeconds,
        accuracyScore: accuracyScore,
        startedAt: startedAt,
      );
    } on AppFailure catch (e) {
      saveError = e.message;
    } catch (_) {
      saveError = 'Không lưu được buổi tập. Kiểm tra kết nối mạng.';
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          exercise: widget.exercise,
          repCount: _repCount,
          durationSeconds: durationSeconds,
          accuracyScore: accuracyScore,
          errorCounts: _errorCounts,
        ),
      ),
    );
    if (saveError != null && mounted) {
      // Giữ thông báo giới hạn gói Free (403 sau 3 buổi/ngày) của nhánh hiepga:
      // màn tổng kết của main không có chỗ hiện lỗi lưu, nên báo bằng SnackBar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saveError)),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transientErrorTimer?.cancel();
    _responseTimeoutTimer?.cancel();
    _socketSub?.cancel();
    _socket.close();
    _controller?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != _SessionStatus.running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _status == _SessionStatus.running) _endSession();
      },
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _SessionStatus.initializing:
      case _SessionStatus.connecting:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                _status == _SessionStatus.initializing
                    ? AppLocale.t('analyze_starting_camera')
                    : AppLocale.t('analyze_connecting'),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      case _SessionStatus.permissionDenied:
        return _MessageScreen(
          icon: Icons.videocam_off_rounded,
          message: AppLocale.t('analyze_permission_denied'),
          actionLabel: AppLocale.t('analyze_open_settings'),
          onAction: openAppSettings,
        );
      case _SessionStatus.error:
        return _MessageScreen(
          icon: Icons.error_outline_rounded,
          message: _statusMessage ?? AppLocale.t('error_generic_short'),
          actionLabel: AppLocale.t('analyze_close'),
          onAction: () => Navigator.of(context).pop(),
        );
      case _SessionStatus.running:
        return _buildAnalyzeView();
    }
  }

  Widget _buildAnalyzeView() {
    final controller = _controller;
    // Controller is null briefly while _flipCamera() disposes the old one
    // and before the new one is assigned — show a spinner instead of
    // crashing on the ! operator.
    if (controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    final guide = GuideVideoPlayer(
      // Re-keyed on the URL so the player rebuilds (and picks up the
      // network video) once _loadGuideVideo resolves after the
      // asset fallback has already started playing.
      key: ValueKey(_guideVideoUrl ?? 'asset'),
      assetPath: guideVideoAssetFor(widget.exercise),
      networkUrl: _guideVideoUrl,
    );

    // Bài chưa có video hướng dẫn thì nhường trọn màn hình cho camera. Giữ
    // nguyên khung 40% để hiện dòng "chưa có video" là lấy mất gần nửa màn
    // hình của đúng thứ người dùng cần nhìn khi đang tập — nhất là trên điện
    // thoại, nơi khung xương và tư thế cần càng to càng tốt.
    if (!guide.hasVideo) return _buildCameraPanel(controller);

    // 40/60 vertical split: guide video on top, camera + live analysis
    // below — flex 2:3 gives the exact 40%/60% ratio.
    return Column(
      children: [
        Expanded(flex: 2, child: guide),
        Expanded(flex: 3, child: _buildCameraPanel(controller)),
      ],
    );
  }

  Color _similarityScoreColor(double score) {
    if (score >= 80) return AppColors.chartGreen;
    if (score >= 50) return Colors.amberAccent;
    return Colors.redAccent;
  }

  Widget _buildCameraPanel(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera + skeleton overlay are composited together inside a
            // box sized to the panel's actual width FIRST (so skeleton
            // alignment against the raw camera frame stays exact, and
            // painted strokes/joint dots keep their real on-screen size
            // instead of being blown up by FittedBox scaling from an
            // arbitrary small base size), then cover-scaled just enough to
            // fill the panel height with no letterboxing.
            //
            // When the sensor is rotated 90/270° (portrait capture on Android),
            // controller.value.aspectRatio returns the pre-rotation landscape
            // ratio. Inverting it gives the actual portrait display ratio so
            // CameraPreview renders without horizontal distortion (which
            // otherwise makes people look short/wide).
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: Builder(
                  builder: (context) {
                    final bool sensorIsPortrait =
                        _rotationDegrees == 90 || _rotationDegrees == 270;
                    final double displayAspect = sensorIsPortrait
                        ? 1.0 / controller.value.aspectRatio
                        : controller.value.aspectRatio;
                    // The camera preview and the skeleton overlay are grouped
                    // into one Stack and mirrored TOGETHER, as a single unit,
                    // for the front camera — not mirrored independently by
                    // two separate, hardcoded decisions (one Transform on
                    // CameraPreview, one flip flag inside SkeletonPainter).
                    //
                    // History: the two-independent-flags version (written
                    // 11/09/2026, see CHANGELOG) assumed CameraPreview does
                    // NOT auto-mirror the front camera on its own — true on
                    // some camera_android_camerax/rendering-backend
                    // combinations, false on others (flutter/flutter#156974
                    // is a known, per-device-inconsistent regression). On a
                    // device where the plugin DOES auto-mirror correctly, the
                    // old code's own Transform mirrored the preview a SECOND
                    // time (net: displayed "like a recording", un-mirrored),
                    // while SkeletonPainter's flag still mirrored the
                    // skeleton exactly once — so the skeleton and the video
                    // ended up disagreeing about which side is which
                    // (confirmed via a real bug-report screenshot,
                    // 14/09/2026: skeleton clearly on the wrong side of the
                    // body during a live session). It's the same underlying
                    // plugin inconsistency as 11/09/2026, just manifesting in
                    // the opposite direction.
                    //
                    // Fixing it by wrapping BOTH children in the same
                    // Transform (instead of just CameraPreview) makes this
                    // whole class of bug structurally impossible: whatever
                    // the plugin does on a given device, the video and the
                    // skeleton are always flipped (or not) together, as one
                    // rigid unit, so they can never disagree. The only
                    // remaining question — whether the front preview visually
                    // looks like "a real mirror" or "like a recording" on any
                    // given device — is now purely cosmetic and still
                    // unknowable from Dart, but it is no longer a
                    // skeleton/video misalignment bug either way.
                    final cameraAndSkeleton = Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        // Coordinates come from the same rotated (never
                        // mirrored) JPEG sent to the backend (see
                        // _encodeCameraImage) — SkeletonPainter always draws
                        // them raw/un-flipped now; mirroring for the front
                        // camera, if any, happens exactly once, geometrically,
                        // via the Transform wrapping this whole Stack.
                        CustomPaint(
                          painter: SkeletonPainter(
                            keypoints: _keypoints,
                            correct: _correct,
                          ),
                        ),
                      ],
                    );
                    return SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxWidth / displayAspect,
                      child: _lensDirection == CameraLensDirection.front
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(pi),
                              child: cameraAndSkeleton,
                            )
                          : cameraAndSkeleton,
                    );
                  },
                ),
              ),
            ),
            if (_isPaused)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: Text(
                  AppLocale.t('analyze_paused'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _endSession,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Analyzing: ${_capitalize(widget.exercise)}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _isFlipping ? null : _flipCamera,
                        icon: const Icon(
                          Icons.flip_camera_android_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: _togglePause,
                        icon: Icon(
                          _isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (_correct ? AppColors.chartGreen : Colors.redAccent)
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    AppLocale.phase(_phase),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
            _buildDebugAngleOverlay(),
            // "Độ giống bài mẫu" — chỉ hiện khi backend trả điểm thật (bài
            // có chuẩn tham chiếu VÀ cửa sổ live đã đủ frame để tính, xem
            // FrameAnalysisResult.similarityScore); `null` ẩn hẳn thay vì
            // hiện 0%, vì 0% sẽ đọc nhầm thành "tập sai hoàn toàn".
            if (_similarityScore != null)
              Positioned(
                top: 90,
                right: 16,
                child: Container(
                  width: 64,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppLocale.t('analyze_similarity_label'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_similarityScore!.round()}%',
                        style: TextStyle(
                          color: _similarityScoreColor(_similarityScore!),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_similarityScore! / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                            _similarityScoreColor(_similarityScore!),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_transientError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _transientError!,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (_errors.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final error in _errors)
                                Text(
                                  error,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_repCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                AppLocale.t('analyze_reps_label'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _isEnding ? null : _endSession,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              AppLocale.t('analyze_end_session'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _MessageScreen extends StatelessWidget {
  const _MessageScreen({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Argument bundle for [_encodeCameraImage] — [compute] takes exactly one
/// message argument, so the frame and its rotation are packed together.
class _EncodeArgs {
  const _EncodeArgs(this.image, this.rotationDegrees);

  final CameraImage image;
  final int rotationDegrees;
}

/// Converts a YUV420 [CameraImage] (Android's `startImageStream` format)
/// into a rotated, JPEG-encoded byte buffer suitable for the analyze
/// socket. Runs inside a background isolate via [compute] so the per-pixel
/// color-space conversion doesn't jank the camera preview.
Uint8List _encodeCameraImage(_EncodeArgs args) {
  final image = args.image;
  final width = image.width;
  final height = image.height;

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  var rgbImage = img.Image(width: width, height: height);

  for (var y = 0; y < height; y++) {
    final yRowOffset = y * yPlane.bytesPerRow;
    final uvRowOffset = (y >> 1) * uPlane.bytesPerRow;
    for (var x = 0; x < width; x++) {
      final yValue = yPlane.bytes[yRowOffset + x];
      final uvIndex = uvRowOffset + (x >> 1) * uvPixelStride;
      final uValue = uPlane.bytes[uvIndex];
      final vValue = vPlane.bytes[uvIndex];

      final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
      final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
          .clamp(0, 255)
          .toInt();
      final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

      rgbImage.setPixelRgb(x, y, r, g, b);
    }
  }

  if (args.rotationDegrees != 0) {
    rgbImage = img.copyRotate(rgbImage, angle: args.rotationDegrees);
  }

  return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 70));
}
