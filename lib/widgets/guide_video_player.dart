import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_theme.dart';

/// Looping demo-technique video panel for [AnalyzeSessionScreen]'s top
/// 40% split. Plays a bundled asset (see `assets/video/`, declared in
/// `pubspec.yaml`) — not a network video, so no loading/buffering states
/// beyond the initial decode.
class GuideVideoPlayer extends StatefulWidget {
  const GuideVideoPlayer({super.key, required this.assetPath});

  final String assetPath;

  @override
  State<GuideVideoPlayer> createState() => _GuideVideoPlayerState();
}

class _GuideVideoPlayerState extends State<GuideVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _isPlaying = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath);
    _controller
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller.play();
      } else {
        _controller.pause();
      }
    });
  }

  void _openFullscreen() {
    _controller.pause();
    setState(() => _isPlaying = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGuideVideo(assetPath: widget.assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Could not load the guide video.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                _CircleIconButton(
                  icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 8),
                _CircleIconButton(icon: Icons.fullscreen_rounded, onPressed: _openFullscreen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Full-screen playback opened via the expand button — a fresh
/// [VideoPlayerController] rather than sharing the panel's, simplest way
/// to avoid juggling controller ownership across two live widgets.
class _FullscreenGuideVideo extends StatefulWidget {
  const _FullscreenGuideVideo({required this.assetPath});

  final String assetPath;

  @override
  State<_FullscreenGuideVideo> createState() => _FullscreenGuideVideoState();
}

class _FullscreenGuideVideoState extends State<_FullscreenGuideVideo> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
