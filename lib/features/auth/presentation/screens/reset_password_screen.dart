import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../utils/password_rules.dart';
import '../../../../widgets/auth_text_field.dart';
import '../../../../widgets/info_tip_card.dart';
import '../../auth_module.dart';
import 'login_screen.dart';

/// Second (final) step of the password-reset flow — the user types the
/// 6-digit code emailed by [ForgotPasswordScreen] (`send_reset_password_email`
/// on the backend, valid 5 minutes, burned after 10 wrong tries), picks a new
/// password, and submits to `POST /api/v1/auth/reset-password`.
///
/// Since 12/11/2026 the backend checks the code against ONE account, so the
/// request carries the email too. When this screen is opened without one
/// ("I already have a code" with an empty email box) it shows an email field.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  /// Email the code was sent to; when null/empty the screen asks for it.
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with AppLocaleMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _hasEmail => widget.email != null && widget.email!.trim().isNotEmpty;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await AuthModule.resetPassword()(
        email: _hasEmail ? widget.email!.trim() : _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocale.t('reset_success_snack'))),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on AppFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = AppLocale.t('error_no_connection'));
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
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.textSecondary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocale.t('reset_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _hasEmail
                    ? AppLocale.format('reset_subtitle_with_email', {'email': widget.email!.trim()})
                    : AppLocale.t('reset_subtitle_no_email'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              if (!_hasEmail) ...[
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
              ],
              AuthTextField(
                label: AppLocale.t('reset_code_label'),
                hint: AppLocale.t('reset_code_hint'),
                icon: Icons.vpn_key_outlined,
                controller: _codeController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (code.isEmpty) return AppLocale.t('validation_enter_reset_code');
                  if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                    return AppLocale.t('validation_reset_code_6_digits');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('reset_new_password_label'),
                hint: AppLocale.t('reset_new_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) return AppLocale.t('validation_enter_new_password');
                  return validateNewPassword(value);
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('reset_confirm_password_label'),
                hint: AppLocale.t('reset_confirm_password_hint'),
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
                title: AppLocale.t('tip_strong_password_title'),
                body: AppLocale.t('tip_strong_password_body'),
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
                          AppLocale.t('reset_submit_button'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
