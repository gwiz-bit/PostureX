import 'package:flutter/material.dart';

import '../models/frame_analysis_result.dart';

/// Bone pairs drawn as lines. Covers the whole body (arms, legs, feet) —
/// not just the handful of joints a given exercise's analyzer happens to
/// use for its own angle math (see [FrameAnalysisResult.allKeypoints]).
/// Face landmarks are deliberately NOT in this list — see [_faceLandmarks].
const _bones = [
  ('left_shoulder', 'right_shoulder'),
  ('left_shoulder', 'left_hip'),
  ('right_shoulder', 'right_hip'),
  ('left_hip', 'right_hip'),
  ('left_shoulder', 'left_elbow'),
  ('left_elbow', 'left_wrist'),
  ('right_shoulder', 'right_elbow'),
  ('right_elbow', 'right_wrist'),
  ('left_hip', 'left_knee'),
  ('left_knee', 'left_ankle'),
  ('right_hip', 'right_knee'),
  ('right_knee', 'right_ankle'),
  ('left_ankle', 'left_heel'),
  ('left_ankle', 'left_foot_index'),
  ('right_ankle', 'right_heel'),
  ('right_ankle', 'right_foot_index'),
];

/// Drawn as small dots only, no connecting lines — a face full of criss-cross
/// bone lines between eyes/ears/mouth reads as clutter, not detail, at the
/// distance people stand from the camera to fit their whole body in frame.
const _faceLandmarks = {
  'nose',
  'left_eye',
  'right_eye',
  'left_ear',
  'right_ear',
  'mouth_left',
  'mouth_right',
};

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

  /// Pass [FrameAnalysisResult.allKeypoints] here, not `.keypoints` — the
  /// latter is only the subset the active exercise's analyzer uses for
  /// angle math (squat has no elbows, curl has no knees), which is why the
  /// overlay used to look like a box around the torso instead of a full
  /// body outline. `allKeypoints` covers the whole body regardless of
  /// exercise (see CHANGELOG 09/09/2026).
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
      if (offset == null) continue;
      canvas.drawCircle(offset, _faceLandmarks.contains(name) ? 4 : 6, jointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) =>
      oldDelegate.keypoints != keypoints ||
      oldDelegate.correct != correct ||
      oldDelegate.mirror != mirror;
}
