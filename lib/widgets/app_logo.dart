import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// PostureX mark — "Balanced X": two crossing diagonal strokes (one full
/// opacity, one dimmed) with a small gap at the intersection, evoking the
/// "X" in PostureX in tension/balance. Hand-drawn with [CustomPainter] so
/// it scales cleanly at any size without bundling an image asset, mirroring
/// the technique used for the Google "G" mark in google_sign_in_button.dart.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter(color ?? AppColors.primary)),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  _AppLogoPainter(this.color);

  final Color color;

  // The gap at the crossing point is drawn independent of any background
  // color (two short segments instead of a knockout dot), so the mark
  // stays correct on any surface it's placed on.
  static const _gap = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokeWidth = w * 0.19;
    final p1 = Offset(w * 0.27, h * 0.27);
    final p2 = Offset(w * 0.73, h * 0.73);
    final p3 = Offset(w * 0.73, h * 0.27);
    final p4 = Offset(w * 0.27, h * 0.73);

    final foreground = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final background = Paint()
      ..color = color.withValues(alpha: color.a * 0.45)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    _drawGappedLine(canvas, p1, p2, foreground);
    _drawGappedLine(canvas, p3, p4, background);
  }

  void _drawGappedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    canvas.drawLine(Offset.lerp(from, to, 0)!, Offset.lerp(from, to, 0.5 - _gap / 2)!, paint);
    canvas.drawLine(Offset.lerp(from, to, 0.5 + _gap / 2)!, Offset.lerp(from, to, 1)!, paint);
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) => oldDelegate.color != color;
}
