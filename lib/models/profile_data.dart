/// Maps the backend's `ProfileOut` schema (UserProfiles + weekly Goal),
/// the subset of onboarding data persisted server-side.
class ProfileData {
  const ProfileData({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.fitnessLevel,
    required this.weeklyGoal,
  });

  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? fitnessLevel;
  final int? weeklyGoal;

  factory ProfileData.fromJson(Map<String, dynamic> json) => ProfileData(
        age: json['age'] as int?,
        gender: json['gender'] as String?,
        heightCm: (json['height_cm'] as num?)?.toDouble(),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        fitnessLevel: json['fitness_level'] as String?,
        weeklyGoal: json['weekly_goal'] as int?,
      );
}
