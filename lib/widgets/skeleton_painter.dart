import 'package:flutter/material.dart';

import '../models/frame_analysis_result.dart';

/// The joint pairs drawn as bones — only covers what the backend's squat
/// analyzer actually sends (shoulders/hips/knees/ankles), not the full
/// 33-point MediaPipe skeleton.
const _bones = [
  ('left_shoulder', 'right_shoulder'),
  ('left_shoulder', 'left_hip'),
  ('right_shoulder', 'right_hip'),
  ('left_hip', 'right_hip'),
  ('left_hip', 'left_knee'),
  ('right_hip', 'right_knee'),
  ('left_knee', 'left_ankle'),
  ('right_knee', 'right_ankle'),
];

/// Draws a stick-figure skeleton over the camera preview from the
/// normalized joint coordinates the analyze socket sends each frame.
/// Green while [correct] is true, red otherwise — the backend only
/// reports a binary correct/incorrect per frame today, not per-joint
/// severity, so that's the full color vocabulary available here.
class SkeletonPainter extends CustomPainter {
  const SkeletonPainter({
    required this.keypoints,
    required this.correct,
    this.mirror = false,
  });

  final Map<String, Point>? keypoints;
  final bool correct;

  /// True when the frames came from the FRONT camera.
  ///
  /// `_encodeCameraImage` sends the backend the raw sensor JPEG (only
  /// rotated, never mirrored) — the pose coordinates it returns are in that
  /// same un-mirrored space. But `CameraPreview` auto-mirrors the front
  /// camera for on-screen display (so it behaves like a real mirror the
  /// user is used to), which this painter draws directly on top of. Without
  /// this flag the two disagree on which side is which, so every joint
  /// lands nowhere near the body it's meant to trace — the skeleton looks
  /// simply absent rather than "slightly off". Back camera has no such
  /// mismatch since `CameraPreview` doesn't mirror it.
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final points = keypoints;
    if (points == null || points.isEmpty) return;

    final color = correct ? const Color(0xFF4CD964) : const Color(0xFFFF3B30);
    final bonePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final jointPaint = Paint()..color = color;

    Offset? offsetFor(String name) {
      final p = points[name];
      if (p == null) return null;
      final x = mirror ? 1 - p.x : p.x;
      return Offset(x * size.width, p.y * size.height);
    }

    for (final (a, b) in _bones) {
      final start = offsetFor(a);
      final end = offsetFor(b);
      if (start != null && end != null) {
        canvas.drawLine(start, end, bonePaint);
      }
    }

    for (final name in points.keys) {
      final offset = offsetFor(name);
      if (offset != null) canvas.drawCircle(offset, 6, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      oldDelegate.keypoints != keypoints ||
      oldDelegate.correct != correct ||
      oldDelegate.mirror != mirror;
}
