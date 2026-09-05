import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/user_session.dart';
import '../theme/app_theme.dart';

/// `/media/exercise-videos/*` requires a signed-in session (see
/// `backend/app/main.py`) — attach the same bearer token `ApiClient` uses,
/// since `VideoPlayerController.networkUrl` bypasses `ApiClient` entirely.
Map<String, String> _guideVideoAuthHeaders() {
  final token = UserSession.accessToken;
  return token == null ? {} : {'Authorization': 'Bearer $token'};
}

/// Khung video hướng dẫn phát lặp — dùng ở [AnalyzeSessionScreen] (40% trên
/// màn hình) và ở màn chi tiết bài tập.
///
/// Ưu tiên [networkUrl] (video của chính bài đó, tải từ server); không có thì
/// dùng asset đóng gói [assetPath].
///
/// **Cả hai đều `null` là chuyện bình thường**, không phải lỗi: 5 trong 417
/// bài của thư viện chưa có video, và app chỉ đóng gói sẵn video squat. Khi đó
/// widget hiện một dòng thông báo thay cho khung video.
///
/// Trước đây [assetPath] là bắt buộc và người gọi luôn truyền vào video squat
/// làm mặc định, nên mọi bài chưa có video đều phát nhầm động tác squat — xem
/// phần lịch sử trong `lib/utils/exercise_videos.dart`.
class GuideVideoPlayer extends StatefulWidget {
  const GuideVideoPlayer({super.key, this.assetPath, this.networkUrl});

  final String? assetPath;
  final String? networkUrl;

  /// Có nguồn nào để phát không. Người gọi có thể hỏi trước để tự quyết định
  /// bố cục, thay vì để widget này chiếm chỗ rồi hiện thông báo.
  bool get hasVideo => networkUrl != null || assetPath != null;

  @override
  State<GuideVideoPlayer> createState() => _GuideVideoPlayerState();
}

/// Chỗ trống khi bài tập chưa có video hướng dẫn.
///
/// Nói thẳng là chưa có, thay vì chiếu video của bài khác. Người dùng đọc
/// xong biết đây là thiếu dữ liệu, không phải app hỏng — và quan trọng hơn,
/// không hiểu nhầm rằng động tác trên màn hình là động tác mình cần tập.
class _NoGuideVideo extends StatelessWidget {
  const _NoGuideVideo();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 28),
              SizedBox(height: 10),
              Text(
                'Bài này chưa có video hướng dẫn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideVideoPlayerState extends State<GuideVideoPlayer> {
  /// `null` khi bài tập không có nguồn video nào. Không dựng controller trong
  /// trường hợp đó — `VideoPlayerController.asset('')` sẽ ném lỗi lúc chạy.
  VideoPlayerController? _controller;
  bool _isPlaying = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final controller = _buildController();
    _controller = controller;
    if (controller == null) return;

    controller
      ..setLooping(true)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        controller.play();
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  VideoPlayerController? _buildController() {
    final url = widget.networkUrl;
    if (url != null) {
      return VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _guideVideoAuthHeaders(),
      );
    }
    final asset = widget.assetPath;
    return asset == null ? null : VideoPlayerController.asset(asset);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        controller.play();
      } else {
        controller.pause();
      }
    });
  }

  void _openFullscreen() {
    _controller?.pause();
    setState(() => _isPlaying = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGuideVideo(assetPath: widget.assetPath, networkUrl: widget.networkUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Không có nguồn video nào — nói thẳng thay vì chiếu video bài khác.
    if (controller == null) return const _NoGuideVideo();

    if (_hasError) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('Không tải được video hướng dẫn.', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
    if (!controller.value.isInitialized) {
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
          // Cover-fill instead of letterboxed AspectRatio, so the video
          // visually fills its whole 40% panel share rather than leaving
          // black bars around a smaller centered rectangle.
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 100,
                height: 100 / controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
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
  const _FullscreenGuideVideo({this.assetPath, this.networkUrl});

  final String? assetPath;
  final String? networkUrl;

  @override
  State<_FullscreenGuideVideo> createState() => _FullscreenGuideVideoState();
}

class _FullscreenGuideVideoState extends State<_FullscreenGuideVideo> {
  /// Không bao giờ `null` trên thực tế — nút mở toàn màn hình chỉ hiện khi
  /// video đã phát được. Vẫn để nullable cho khớp kiểu, thay vì `!` sẽ nổ nếu
  /// sau này có ai mở màn này bằng đường khác.
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    final url = widget.networkUrl;
    final asset = widget.assetPath;
    final controller = url != null
        ? VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: _guideVideoAuthHeaders(),
          )
        : (asset == null ? null : VideoPlayerController.asset(asset));
    _controller = controller;
    if (controller == null) return;

    controller
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        controller.play();
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller == null)
            const _NoGuideVideo()
          else if (controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
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
