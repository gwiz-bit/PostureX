import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../screens/main_shell.dart';
import '../../../../screens/onboarding/onboarding_flow.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/app_logo.dart';
import '../../../../widgets/auth_text_field.dart';
import '../../../../features/admin_dashboard/presentation/screens/home_screen.dart' as admin;
import '../../auth_module.dart';

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

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with AppLocaleMixin {
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

  String _friendlyMessage(AppFailure e) {
    switch (e.message) {
      case 'Mã OTP không đúng hoặc đã hết hạn.':
        return AppLocale.t('otp_error_invalid');
      case 'Không tìm thấy tài khoản.':
        return AppLocale.t('otp_error_not_found');
      default:
        return AppLocale.t('error_generic');
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
      final result = await AuthModule.verifyOtp()(
        email: widget.email,
        otpCode: _otpController.text.trim(),
        isFreshRegistration: widget.name != null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) {
            if (widget.name != null) return OnboardingFlow(name: widget.name!);
            return result.isAdmin ? const admin.HomeScreen() : const MainShell();
          },
        ),
      );
    } on AppFailure catch (e) {
      setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      setState(() => _errorMessage = AppLocale.t('error_no_connection'));
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
      await AuthModule.resendOtp()(email: widget.email);
      if (mounted) setState(() => _infoMessage = AppLocale.t('otp_resend_success'));
    } on AppFailure catch (e) {
      if (mounted) setState(() => _errorMessage = _friendlyMessage(e));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = AppLocale.t('error_no_connection'));
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
              Text(
                AppLocale.t('otp_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocale.format('otp_subtitle', {'email': widget.email}),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 36),
              AuthTextField(
                label: AppLocale.t('otp_field_label'),
                hint: AppLocale.t('otp_field_hint'),
                icon: Icons.pin_outlined,
                controller: _otpController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppLocale.t('validation_enter_code');
                  if (value.trim().length != 6) return AppLocale.t('validation_code_6_digits');
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
                      : Text(
                          AppLocale.t('otp_verify_button'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocale.t('otp_no_code'),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? AppLocale.t('otp_sending') : AppLocale.t('otp_resend'),
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
