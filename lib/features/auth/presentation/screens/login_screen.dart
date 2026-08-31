import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../screens/main_shell.dart';
import '../../../../screens/onboarding/onboarding_flow.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/app_logo.dart';
import '../../../../widgets/auth_text_field.dart';
import '../../../../widgets/google_sign_in_button.dart';
import '../../../../widgets/or_divider.dart';
import '../../../../features/admin_dashboard/presentation/screens/home_screen.dart' as admin;
import '../../auth_module.dart';
import 'forgot_password_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with AppLocaleMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _needsVerification = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Known, fixed backend error strings (Vietnamese) mapped to English to
  /// match the rest of the UI. Anything else falls back to a generic
  /// message rather than showing an unmapped Vietnamese string.
  static const _unverifiedEmailDetail =
      'Email chưa được xác thực. Vui lòng nhập mã OTP đã gửi tới email.';

  String _friendlyMessage(AppFailure e) {
    switch (e.message) {
      case 'Email hoặc mật khẩu không đúng.':
        return AppLocale.t('login_error_wrong_credentials');
      case 'Tài khoản không tồn tại.':
        return AppLocale.t('login_error_account_not_found');
      case _unverifiedEmailDetail:
        return AppLocale.t('login_error_not_verified');
      default:
        return AppLocale.t('error_generic');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _needsVerification = false;
    });

    try {
      final email = _emailController.text.trim();
      final result = await AuthModule.login()(
        email: email,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => result.isAdmin ? const admin.HomeScreen() : const MainShell(),
        ),
      );
    } on AppFailure catch (e) {
      setState(() {
        _errorMessage = _friendlyMessage(e);
        _needsVerification = e.message == _unverifiedEmailDetail;
      });
    } catch (_) {
      setState(() => _errorMessage = AppLocale.t('error_no_connection'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToOtpVerification() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(email: _emailController.text.trim()),
      ),
    );
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthModule.loginWithGoogle()();
      if (result == null) return; // user dismissed the account picker
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            if (result.isNewUser) return OnboardingFlow(name: result.fullName ?? '');
            return result.isAdmin ? const admin.HomeScreen() : const MainShell();
          },
        ),
      );
    } on AppFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      setState(() => _errorMessage = AppLocale.t('login_google_error'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const AppLogo(size: 28, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                AppLocale.t('login_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocale.t('login_subtitle'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: AppLocale.t('field_email_label'),
                hint: AppLocale.t('field_email_hint'),
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppLocale.t('validation_enter_email');
                  if (!value.contains('@')) return AppLocale.t('validation_invalid_email');
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('field_password_label'),
                hint: AppLocale.t('field_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.isEmpty) return AppLocale.t('validation_enter_password');
                  if (value.length < 6) return AppLocale.t('validation_min_6_chars');
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                  child: Text(
                    AppLocale.t('login_forgot_password'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                if (_needsVerification) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _goToOtpVerification,
                    child: Text(
                      AppLocale.t('login_verify_now'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation(AppColors.onPrimary),
                          ),
                        )
                      : Text(
                          AppLocale.t('login_button'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const OrDivider(),
              const SizedBox(height: 24),
              GoogleSignInButton(onPressed: _continueWithGoogle),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocale.t('login_no_account'),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _goToRegister,
                    child: Text(
                      AppLocale.t('login_sign_up_link'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
