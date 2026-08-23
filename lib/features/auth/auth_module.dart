import '../../services/api_client.dart';
import 'data/datasources/auth_remote_data_source.dart';
import 'data/repositories/session_repository_impl.dart';
import 'domain/repositories/session_repository.dart';
import 'domain/usecases/forgot_password.dart';
import 'domain/usecases/login.dart';
import 'domain/usecases/login_with_google.dart';
import 'domain/usecases/register.dart';
import 'domain/usecases/resend_otp.dart';
import 'domain/usecases/reset_password.dart';
import 'domain/usecases/verify_otp.dart';

/// Manual composition root for the Auth feature.
class AuthModule {
  AuthModule._();

  static SessionRepository _repository() =>
      SessionRepositoryImpl(AuthRemoteDataSource(ApiClient.instance));

  static Login login() => Login(_repository());

  static Register register() => Register(_repository());

  static VerifyOtp verifyOtp() => VerifyOtp(_repository());

  static ResendOtp resendOtp() => ResendOtp(_repository());

  static LoginWithGoogle loginWithGoogle() => LoginWithGoogle(_repository());

  static ForgotPassword forgotPassword() => ForgotPassword(_repository());

  static ResetPassword resetPassword() => ResetPassword(_repository());
}
