import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../admin/screens/home_screen.dart' as admin;
import 'main_shell.dart';
import 'onboarding/onboarding_flow.dart';

/// Shown right after registration (or when login reports an unverified
/// email) — the account already exists server-side but can't log in until
/// this OTP is confirmed via POST /api/v1/auth/verify-otp.
///
/// [name] is only supplied on the fresh-registration path, where a
/// successful verify continues into [OnboardingFlow]; when reached from
/// Login (an existing but unverified account) it's left null and a
/// successful verify goes straight to [MainShell] instead.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.email, this.name});

  final String email;
  final String? name;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  String _friendlyMessage(ApiException e) {
    switch (e.message) {
      case 'Mã OTP không đúng hoặc đã hết hạn.':
        return 'Incorrect or expired code. Please try again.';
      case 'Không tìm thấy tài khoản.':
        return 'Account not found.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final auth = await ApiClient.instance.verifyOtp(
        email: widget.email,
        otpCode: _otpController.text.trim(),
      );
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
        // Best-effort — the user stays logged in for this run either way.
      }

      UserSession.hasCompletedOnboarding = widget.name == null;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            if (widget.name != null) return OnboardingFlow(name: widget.name!);
            return profile.isAdmin ? const admin.HomeScreen() : const MainShell();
          },
        ),
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ApiClient.instance.resendOtp(email: widget.email);
      if (mounted) setState(() => _infoMessage = 'A new code has been sent to your email.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
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
              const Text(
                'Check your email',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code we sent to ${widget.email}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: 'Verification code',
                hint: '123456',
                icon: Icons.pin_outlined,
                controller: _otpController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter the code';
                  if (value.trim().length != 6) return 'Code must be 6 digits';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              if (_infoMessage != null) ...[
                Text(
                  _infoMessage!,
                  style: const TextStyle(color: AppColors.chartGreen, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _verify,
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
                          'Verify',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't get the code? ",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? 'Sending...' : 'Resend',
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
