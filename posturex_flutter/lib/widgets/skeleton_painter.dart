import 'package:flutter/material.dart';

class SkeletonPainter extends CustomPainter {
  final Color color;
  final bool highlightError;

  SkeletonPainter({required this.color, this.highlightError = false});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color;

    final scaleX = size.width / 240;
    final scaleY = size.height / 220;
    Offset p(double x, double y) => Offset(x * scaleX, y * scaleY);

    canvas.drawCircle(p(120, 34), 11 * scaleX, linePaint);
    canvas.drawLine(p(120, 45), p(120, 105), linePaint);
    canvas.drawLine(p(120, 105), p(92, 150), linePaint);
    canvas.drawLine(p(120, 105), p(148, 150), linePaint);
    canvas.drawLine(p(92, 150), p(90, 202), linePaint);
    canvas.drawLine(p(148, 150), p(150, 202), linePaint);
    canvas.drawLine(p(120, 68), p(82, 94), linePaint);
    canvas.drawLine(p(120, 68), p(158, 94), linePaint);

    final joints = [
      p(120, 45),
      p(120, 68),
      p(82, 94),
      p(158, 94),
      p(120, 105),
      p(92, 150),
      p(148, 150),
      p(90, 202),
      p(150, 202),
    ];
    for (final joint in joints) {
      canvas.drawCircle(joint, 3, dotPaint);
    }

    if (highlightError) {
      final errorPaint = Paint()
        ..color = const Color(0xFFE24B4A)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p(92, 150), 8 * scaleX, errorPaint);
      canvas.drawCircle(p(148, 150), 8 * scaleX, errorPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.highlightError != highlightError;
}
