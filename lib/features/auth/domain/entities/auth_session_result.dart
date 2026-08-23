/// What a screen needs to know after a successful login/register-OTP/Google
/// flow to decide where to navigate — everything else (persisting the
/// session, updating the app-wide session) already happened inside the
/// repository before this is returned.
class AuthSessionResult {
  const AuthSessionResult({
    required this.isAdmin,
    required this.isNewUser,
    required this.fullName,
  });

  final bool isAdmin;
  final bool isNewUser;
  final String? fullName;
}
