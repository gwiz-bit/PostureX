/// Maps the backend's `UserOut` schema. Not to be confused with
/// [OnboardingProfile] (lib/models/onboarding_profile.dart), which holds
/// purely client-side onboarding answers with no backend equivalent.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.isAdmin,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String? fullName;
  final bool isActive;
  final bool isAdmin;
  final DateTime createdAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String?,
        isActive: json['is_active'] as bool,
        isAdmin: json['is_admin'] as bool,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
