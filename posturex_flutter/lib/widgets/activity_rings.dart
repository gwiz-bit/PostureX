import 'dart:math';
import 'package:flutter/material.dart';

class RingData {
  final Color background;
  final Color foreground;
  final double progress;

  const RingData({
    required this.background,
    required this.foreground,
    required this.progress,
  });
}

class _ActivityRingsPainter extends CustomPainter {
  final List<RingData> rings;

  static const double strokeWidth = 11;
  static const double gap = 3;

  _ActivityRingsPainter({required this.rings});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2 - strokeWidth / 2;

    for (final ring in rings) {
      final backgroundPaint = Paint()
        ..color = ring.background
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke;
      final foregroundPaint = Paint()
        ..color = ring.foreground
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, backgroundPaint);
      final sweepAngle = 2 * pi * ring.progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        foregroundPaint,
      );
      radius -= strokeWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ActivityRingsPainter oldDelegate) => true;
}

class ActivityRings extends StatelessWidget {
  final double size;
  final List<RingData> rings;

  const ActivityRings({super.key, required this.size, required this.rings});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ActivityRingsPainter(rings: rings)),
    );
  }
}
