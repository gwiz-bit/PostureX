import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../config/api_config.dart';
import '../models/frame_analysis_result.dart';
import '../services/analyze_socket_service.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
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
const _frameInterval = Duration(milliseconds: 110); // ~9 fps cap

/// How many consecutive frames the same mistake category must appear in
/// before it gets read aloud via TTS. At the ~9fps frame cap this is under
/// half a second — short, but matches "lặp lại 3 lần liên tiếp" literally;
/// tune here if that turns out to fire too eagerly in practice.
const _ttsRepeatThreshold = 3;

/// Full-screen camera capture that streams frames to the backend's
/// `/api/v1/ws/analyze` WebSocket and renders live rep-count/phase/error
/// feedback. Only "squat" is registered on the backend today — every entry
/// point in [WorkoutScreen] launches this with exercise: 'squat', labelled
/// honestly on screen rather than pretending other exercises are analyzed.
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

class _AnalyzeSessionScreenState extends State<AnalyzeSessionScreen>
    with WidgetsBindingObserver {
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

  bool _awaitingResponse = false;
  DateTime? _lastFrameSentAt;
  DateTime? _sessionStart;
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
      final exercises = await ApiClient.instance.fetchExercises();
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
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _rotationDegrees = camera.sensorOrientation;

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
          _statusMessage = 'Could not start the camera or reach the server.';
        });
      }
    }
  }

  Future<void> _reinitializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
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
      _awaitingResponse = false;
      if (!frame.errors.contains(_noPersonMessage)) {
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
        _keypoints = frame.keypoints;
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
    _encodeAndSend(image);
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
      await ApiClient.instance.createWorkout(
        exercise: widget.exercise,
        totalReps: _repCount,
        durationSeconds: durationSeconds,
        accuracyScore: accuracyScore,
        startedAt: startedAt,
      );
    } on ApiException catch (e) {
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
                    ? 'Starting camera…'
                    : 'Connecting to analysis server…',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      case _SessionStatus.permissionDenied:
        return _MessageScreen(
          icon: Icons.videocam_off_rounded,
          message: 'Camera permission is required to analyze your form.',
          actionLabel: 'Open Settings',
          onAction: openAppSettings,
        );
      case _SessionStatus.error:
        return _MessageScreen(
          icon: Icons.error_outline_rounded,
          message: _statusMessage ?? 'Something went wrong.',
          actionLabel: 'Close',
          onAction: () => Navigator.of(context).pop(),
        );
      case _SessionStatus.running:
        return _buildAnalyzeView();
    }
  }

  Widget _buildAnalyzeView() {
    final controller = _controller!;
    // 40/60 vertical split: guide video on top, camera + live analysis
    // below — flex 2:3 gives the exact 40%/60% ratio.
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: GuideVideoPlayer(
            // Re-keyed on the URL so the player rebuilds (and picks up the
            // network video) once _loadGuideVideo resolves after the
            // asset fallback has already started playing.
            key: ValueKey(_guideVideoUrl ?? 'asset'),
            assetPath: guideVideoAssetFor(widget.exercise),
            networkUrl: _guideVideoUrl,
          ),
        ),
        Expanded(flex: 3, child: _buildCameraPanel(controller)),
      ],
    );
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
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxWidth / controller.value.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(controller),
                      // Coordinates come from the same rotated JPEG sent to
                      // the backend (see _encodeCameraImage), so they line
                      // up with CameraPreview as long as both are scaled
                      // together by the same FittedBox above.
                      CustomPaint(
                        painter: SkeletonPainter(
                          keypoints: _keypoints,
                          correct: _correct,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isPaused)
              Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: const Text(
                  'PAUSED',
                  style: TextStyle(
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
                      Container(
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
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
                    _phase.replaceAll('_', ' ').toUpperCase(),
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
                              const Text(
                                'REPS',
                                style: TextStyle(
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
                            child: const Text(
                              'End Session',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
