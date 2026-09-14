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
///
/// Always draws the RAW, un-mirrored coordinates the backend returns
/// (`_encodeCameraImage` in `AnalyzeSessionScreen` only rotates the sensor
/// JPEG, never mirrors it, so this is the space the backend's pose
/// coordinates are already in). This class deliberately knows nothing about
/// which camera (front/back) is active — mirroring the front camera's view,
/// when needed, is done exactly once, geometrically, by wrapping BOTH the
/// `CameraPreview` and this `CustomPaint` together in a single `Transform`
/// in `AnalyzeSessionScreen.build()`. A `Transform` flips a canvas's draw
/// calls the same way it flips a texture, so grouping them under one
/// transform keeps the skeleton and the video always in agreement about
/// which side is which — regardless of whether the camera plugin happens to
/// auto-mirror the front preview on a given device.
///
/// This used to carry its own `mirror` flag, independently toggled from the
/// same `CameraLensDirection` check that wrapped `CameraPreview` in a
/// `Transform` — two separately-hardcoded mirror decisions that only agreed
/// as long as an unverifiable assumption about the camera plugin's behavior
/// held. On a real device where that assumption didn't hold (confirmed via a
/// bug-report screenshot, 14/09/2026 — see CHANGELOG), the video ended up
/// mirrored twice (net: not mirrored) while this class still mirrored the
/// skeleton once, so they disagreed about which side of the body was which.
/// Removing this flag and folding mirroring into the parent `Transform`
/// makes that whole class of bug structurally impossible.
class SkeletonPainter extends CustomPainter {
  const SkeletonPainter({
    required this.keypoints,
    required this.correct,
  });

  /// Pass [FrameAnalysisResult.allKeypoints] here, not `.keypoints` — the
  /// latter is only the subset the active exercise's analyzer uses for
  /// angle math (squat has no elbows, curl has no knees), which is why the
  /// overlay used to look like a box around the torso instead of a full
  /// body outline. `allKeypoints` covers the whole body regardless of
  /// exercise (see CHANGELOG 09/09/2026).
  final Map<String, Point>? keypoints;
  final bool correct;

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
      return Offset(p.x * size.width, p.y * size.height);
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
      oldDelegate.keypoints != keypoints || oldDelegate.correct != correct;
}
