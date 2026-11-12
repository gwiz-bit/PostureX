import '../../../../models/auth_response.dart';
import '../../../../models/user_profile.dart';
import '../../../../services/api_client.dart';

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<UserProfile> register({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _client.register(email: email, password: password, fullName: fullName);
  }

  Future<AuthResponse> verifyOtp({required String email, required String otpCode}) {
    return _client.verifyOtp(email: email, otpCode: otpCode);
  }

  Future<void> resendOtp({required String email}) => _client.resendOtp(email: email);

  Future<AuthResponse> login({required String email, required String password}) {
    return _client.login(email: email, password: password);
  }

  Future<AuthResponse> loginWithGoogle({required String idToken}) {
    return _client.loginWithGoogle(idToken: idToken);
  }

  Future<void> forgotPassword({required String email}) => _client.forgotPassword(email: email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) {
    return _client.resetPassword(
      token: token,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<UserProfile> fetchMe() => _client.fetchMe();
}
