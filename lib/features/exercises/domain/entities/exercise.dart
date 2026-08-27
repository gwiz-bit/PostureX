/// Read-only exercise info shown to regular users (browse list, detail
/// screen, guide video lookup). Deliberately separate from the admin app's
/// `AdminExercise` — that one carries CRUD-only fields (`isActive`,
/// `exerciseType`) this feature has no business depending on.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.demoVideoUrl,
    this.muscleGroups = const [],
    this.supportsAnalysis = false,
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String? demoVideoUrl;

  /// Muscle groups this exercise targets, primary one first — what the
  /// library screen filters by. The seeded exercises predate the muscle-group
  /// import and can still come back with none, so this may be empty.
  final List<String> muscleGroups;

  /// Whether live posture analysis is available for this exercise. Only ~9 of
  /// the 400+ library exercises have a real analyzer; the rest must not offer
  /// "Start Live Analysis" at all, because the server silently falls back to
  /// squat analysis and would read out squat cues for, say, a calf raise.
  final bool supportsAnalysis;
}
