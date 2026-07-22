class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    this.isNewUser = false,
  });

  final String accessToken;
  final String tokenType;

  /// True only for a Google sign-in that just auto-created the account —
  /// callers use this to route into onboarding instead of straight to
  /// Home, matching the email/OTP registration flow.
  final bool isNewUser;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String,
        isNewUser: json['is_new_user'] as bool? ?? false,
      );
}
