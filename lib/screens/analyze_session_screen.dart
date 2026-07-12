import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../services/analyze_socket_service.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';

enum _SessionStatus { initializing, permissionDenied, connecting, running, error }

const _noPersonMessage = 'Không phát hiện được người trong frame.';
const _frameInterval = Duration(milliseconds: 110); // ~9 fps cap

/// Full-screen camera capture that streams frames to the backend's
/// `/api/v1/ws/analyze` WebSocket and renders live rep-count/phase/error
/// feedback. Only "squat" is registered on the backend today — every entry
/// point in [WorkoutScreen] launches this with exercise: 'squat', labelled
/// honestly on screen rather than pretending other exercises are analyzed.
class AnalyzeSessionScreen extends StatefulWidget {
  const AnalyzeSessionScreen({super.key, required this.exercise, this.routineName});

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
  final List<bool> _correctnessSamples = [];

  bool _awaitingResponse = false;
  DateTime? _lastFrameSentAt;
  DateTime? _sessionStart;
  bool _isEnding = false;
  String? _transientError;
  Timer? _transientErrorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
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

      final controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
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
      final controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false);
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

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
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
      setState(() {
        _repCount = frame.repCount;
        _phase = frame.phase;
        _correct = frame.correct;
        _errors = frame.errors;
      });
      return;
    }

    if (event.error != null) {
      _awaitingResponse = false;
      _showTransientError(event.error!);
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
    if (_status != _SessionStatus.running || _awaitingResponse) return;
    final now = DateTime.now();
    if (_lastFrameSentAt != null && now.difference(_lastFrameSentAt!) < _frameInterval) return;
    _lastFrameSentAt = now;
    _awaitingResponse = true;
    _encodeAndSend(image);
  }

  Future<void> _encodeAndSend(CameraImage image) async {
    try {
      final jpeg = await compute(_encodeCameraImage, _EncodeArgs(image, _rotationDegrees));
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
    final durationSeconds = DateTime.now().difference(startedAt).inSeconds.toDouble();
    final accuracyScore = _correctnessSamples.isEmpty
        ? null
        : _correctnessSamples.where((c) => c).length / _correctnessSamples.length * 100;

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
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Session complete',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(label: 'Reps', value: '$_repCount'),
            _SummaryRow(
              label: 'Duration',
              value: '${durationSeconds.round()}s',
            ),
            _SummaryRow(
              label: 'Accuracy',
              value: accuracyScore == null ? '—' : '${accuracyScore.round()}%',
            ),
            if (saveError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        saveError,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Done'),
          ),
        ],
      ),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _status != _SessionStatus.running,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _status == _SessionStatus.running) _endSession();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildBody(),
      ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
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
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Analyzing: ${_capitalize(widget.exercise)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: (_correct ? AppColors.chartGreen : Colors.redAccent).withValues(alpha: 0.85),
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
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
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
                              style: const TextStyle(color: Colors.white, fontSize: 12),
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
                          const Text('REPS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _isEnding ? null : _endSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        child: const Text('End Session', style: TextStyle(fontWeight: FontWeight.w700)),
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
  }
}

String _capitalize(String value) => value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

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
