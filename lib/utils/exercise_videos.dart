/// Maps an exercise name to its guide-video asset path (see
/// `assets/video/`, declared in `pubspec.yaml`).
///
/// Mirrors the backend's `ANALYZER_REGISTRY` fallback behavior
/// (`app/api/v1/routes/realtime.py`) — any exercise without a real
/// analyzer silently falls back to the squat analyzer server-side, so
/// falling back to the squat guide video here for unmapped exercises is
/// consistent rather than misleading (the pose feedback really is squat
/// feedback either way, whatever video plays alongside it).
///
/// Add a new entry here once a verified (not just correctly-named) video
/// asset exists for that exercise — see the 94 unverified files still
/// sitting in `lib/backend/video/`.
const Map<String, String> _guideVideoByExercise = {
  'squat': 'assets/video/squat.mp4',
};

const _defaultGuideVideo = 'assets/video/squat.mp4';

String guideVideoAssetFor(String exercise) =>
    _guideVideoByExercise[exercise.toLowerCase()] ?? _defaultGuideVideo;
