import 'package:flutter/material.dart';

import '../../../../core/errors/failures.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/app_locale.dart';
import '../../../../widgets/auth_text_field.dart';
import '../../../../widgets/info_tip_card.dart';
import '../../auth_module.dart';
import 'reset_password_screen.dart';

/// First step of the password-reset flow — collects the account email and
/// triggers `POST /api/v1/auth/forgot-password`. The backend always
/// responds with the same generic message regardless of whether the email
/// is registered (anti-enumeration), so this screen always proceeds to
/// [ResetPasswordScreen] on a successful (200) response — there is no
/// "email sent" vs "email not found" branch to show.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with AppLocaleMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await AuthModule.forgotPassword()(email: email);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
      );
    } on AppFailure catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = AppLocale.t('error_no_connection'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _goToResetScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(email: _emailController.text.trim()),
      ),
    );
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
                AppLocale.t('forgot_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocale.t('forgot_subtitle'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: AppLocale.t('field_email_label'),
                hint: AppLocale.t('field_email_hint'),
                icon: Icons.mail_outline_rounded,
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return AppLocale.t('validation_enter_email');
                  if (!value.contains('@')) return AppLocale.t('validation_invalid_email');
                  return null;
                },
              ),
              const SizedBox(height: 20),
              InfoTipCard(
                emoji: '📧',
                title: AppLocale.t('forgot_tip_title'),
                body: AppLocale.t('forgot_tip_body'),
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
                          AppLocale.t('forgot_send_button'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _goToResetScreen,
                  child: Text(
                    AppLocale.t('forgot_already_have_code'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
