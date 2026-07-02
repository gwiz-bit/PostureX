import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_painter.dart';

class CameraScreen extends StatefulWidget {
  final String exerciseName;
  final VoidCallback onOpenProfile;

  const CameraScreen({
    super.key,
    required this.exerciseName,
    required this.onOpenProfile,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _demoPlaying = false;
  bool _tracking = false;
  int _repCount = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTracking() {
    setState(() => _tracking = !_tracking);
    if (_tracking) {
      _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        setState(() => _repCount++);
      });
    } else {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.exerciseName,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: widget.onOpenProfile,
                  child: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.border,
                    child:
                        Icon(Icons.person, size: 16, color: AppColors.gray),
                  ),
                ),
              ],
            ),
          ),
          // Phần trên: video mẫu
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF0C0C0C),
                  child: Column(
                    children: [
                      Expanded(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: SkeletonPainter(color: AppColors.gray),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: 0.3,
                                minHeight: 3,
                                backgroundColor: AppColors.border,
                                valueColor:
                                    const AlwaysStoppedAnimation(AppColors.gray),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _demoPlaying
                                  ? 'Đang phát video mẫu'
                                  : 'Video mẫu',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Video mẫu',
                        style:
                            TextStyle(color: Color(0xFFD3D1C7), fontSize: 10)),
                  ),
                ),
                if (!_demoPlaying)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _demoPlaying = true),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Phần dưới: camera theo dõi trực tiếp
          Expanded(
            child: Container(
              color: AppColors.surfaceAlt,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Camera của bạn',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 10)),
                        Text(
                          _tracking ? 'Đang theo dõi' : 'Sẵn sàng',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: SkeletonPainter(color: AppColors.teal),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SỐ LẦN',
                                style: TextStyle(
                                    color: Color(0xFFA8A6A0), fontSize: 11)),
                            Text('$_repCount',
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _toggleTracking,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _tracking ? AppColors.red : AppColors.teal,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _tracking ? Icons.pause : Icons.play_arrow,
                              color:
                                  _tracking ? Colors.white : AppColors.tealDark,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
