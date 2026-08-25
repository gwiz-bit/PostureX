/// Shared numeric bounds for body-metric fields collected during onboarding
/// and editable afterwards on Edit Profile — kept in one place so the
/// picker ranges, the Edit Profile form validators, and the backend's
/// `ProfileUpdate` schema (`backend/app/schemas/profile.py`) stay in sync
/// instead of drifting as magic numbers duplicated across screens/layers.
class ProfileLimits {
  const ProfileLimits._();

  static const heightCmMin = 140;
  static const heightCmMax = 220;
  static const weightKgMin = 35;
  static const weightKgMax = 180;
}
