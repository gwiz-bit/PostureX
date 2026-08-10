import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/google_auth_service.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/info_tip_card.dart';
import '../widgets/or_divider.dart';
import '../admin/screens/home_screen.dart' as admin;
import 'main_shell.dart';
import 'onboarding/onboarding_flow.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  String _friendlyMessage(ApiException e) {
    switch (e.message) {
      case 'Email đã được sử dụng.':
        return 'That email is already registered.';
      default:
        return 'Something went wrong. Please try again.';
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
      // can log in, so there's no token to apply here yet.
      await ApiClient.instance.register(email: email, password: password, fullName: name);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpVerificationScreen(email: email, name: name)),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
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
      final idToken = await GoogleAuthService.signInAndGetIdToken();
      if (idToken == null) return; // user dismissed the account picker

      final auth = await ApiClient.instance.loginWithGoogle(idToken: idToken);
      UserSession.accessToken = auth.accessToken;
      final profile = await ApiClient.instance.fetchMe();
      UserSession.applyAuthSession(
        userId: profile.id,
        email: profile.email,
        fullName: profile.fullName,
        accessToken: auth.accessToken,
        isAdmin: profile.isAdmin,
      );
      try {
        await TokenStorage.saveSession(
          accessToken: auth.accessToken,
          userId: profile.id,
          email: profile.email,
        );
      } catch (_) {
        // Persisting the session is best-effort, same as the email/password flow.
      }
      UserSession.hasCompletedOnboarding = !auth.isNewUser;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            if (auth.isNewUser) return OnboardingFlow(name: profile.fullName ?? '');
            return profile.isAdmin ? const admin.HomeScreen() : const MainShell();
          },
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      setState(() => _errorMessage = 'Could not sign in with Google. Check your connection.');
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
              const Text(
                'Create your account',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell us a bit about you to personalize your training',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: 'Name',
                hint: 'Your name',
                icon: Icons.person_outline_rounded,
                controller: _nameController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter your email';
                  if (!value.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a password';
                  if (value.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Confirm password',
                hint: 'Re-enter your password',
                icon: Icons.lock_outline_rounded,
                controller: _confirmPasswordController,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const InfoTipCard(
                emoji: '🔒',
                title: 'Your data stays private',
                body: 'We only use your info to personalize your posture insights — never '
                    'shared without your consent.',
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
                      : const Text(
                          'Create account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const OrDivider(),
              const SizedBox(height: 24),
              GoogleSignInButton(
                label: 'Sign up with Google',
                onPressed: _continueWithGoogle,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Log in',
                      style: TextStyle(
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
