class AdminExercise {
  const AdminExercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.exerciseType,
    required this.isActive,
    required this.demoVideoUrl,
    this.muscleGroups = const [],
    this.supportsAnalysis = false,
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String exerciseType;
  final bool isActive;
  final String? demoVideoUrl;

  /// Muscle groups the exercise targets, primary one first. Comes from
  /// `GET /exercises`; the admin CRUD endpoints don't return it, hence the
  /// empty default rather than a required field.
  final List<String> muscleGroups;

  /// Whether the backend has a real posture analyzer for this exercise. The
  /// library holds 400+ exercises but only 9 analyzers — without this flag the
  /// app would let someone start a live session on a neck exercise and have it
  /// read out squat feedback (the server falls back to `SquatAnalyzer`).
  final bool supportsAnalysis;

  factory AdminExercise.fromJson(Map<String, dynamic> json) => AdminExercise(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        difficulty: json['difficulty'] as String?,
        exerciseType: json['exercise_type'] as String,
        isActive: json['is_active'] as bool,
        demoVideoUrl: json['demo_video_url'] as String?,
        muscleGroups:
            (json['muscle_groups'] as List<dynamic>? ?? const []).cast<String>(),
        supportsAnalysis: json['supports_analysis'] as bool? ?? false,
      );
}
