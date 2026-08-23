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
  });

  final int id;
  final String name;
  final String? description;
  final String? category;
  final String? difficulty;
  final String exerciseType;
  final bool isActive;
  final String? demoVideoUrl;

  factory AdminExercise.fromJson(Map<String, dynamic> json) => AdminExercise(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        difficulty: json['difficulty'] as String?,
        exerciseType: json['exercise_type'] as String,
        isActive: json['is_active'] as bool,
        demoVideoUrl: json['demo_video_url'] as String?,
      );
}
