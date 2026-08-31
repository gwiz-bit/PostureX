import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../screens/main_shell.dart';
import '../../../../screens/onboarding/onboarding_flow.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/auth_text_field.dart';
import '../../../../widgets/google_sign_in_button.dart';
import '../../../../widgets/info_tip_card.dart';
import '../../../../widgets/or_divider.dart';
import '../../../../features/admin_dashboard/presentation/screens/home_screen.dart' as admin;
import '../../auth_module.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with AppLocaleMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _friendlyMessage(AppFailure e) {
    switch (e.message) {
      case 'Email đã được sử dụng.':
        return AppLocale.t('register_error_email_taken');
      default:
        return AppLocale.t('error_generic');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Account is created unverified — the backend emails an OTP that
      // must be confirmed (see OtpVerificationScreen) before the account
      // can log in, so there's no session to establish here yet.
      await AuthModule.register()(email: email, password: password, fullName: name);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email, name: name)),
      );
    } on AppFailure catch (e) {
      setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      setState(() => _errorMessage = AppLocale.t('error_no_connection'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocale.t('register_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocale.t('register_subtitle'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: AppLocale.t('field_name_label'),
                hint: AppLocale.t('field_name_hint'),
                icon: Icons.person_outline_rounded,
                controller: _nameController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppLocale.t('validation_enter_name');
                  return null;
                },
              ),
              const SizedBox(height: 18),
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
                hint: AppLocale.t('register_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) return AppLocale.t('validation_enter_password');
                  if (value.length < 6) return AppLocale.t('validation_min_6_chars');
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('register_confirm_password_label'),
                hint: AppLocale.t('register_confirm_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _confirmPasswordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != _passwordController.text) return AppLocale.t('validation_passwords_mismatch');
                  return null;
                },
              ),
              const SizedBox(height: 20),
              InfoTipCard(
                emoji: '🔒',
                title: AppLocale.t('register_tip_title'),
                body: AppLocale.t('register_tip_body'),
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
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
                          AppLocale.t('register_button'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const OrDivider(),
              const SizedBox(height: 24),
              GoogleSignInButton(
                label: AppLocale.t('register_google_button'),
                onPressed: _continueWithGoogle,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocale.t('register_have_account'),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLocale.t('register_log_in_link'),
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
