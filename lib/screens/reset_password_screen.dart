import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/info_tip_card.dart';
import 'login_screen.dart';

/// Second (final) step of the password-reset flow — the user pastes the
/// reset code emailed by [ForgotPasswordScreen] (`send_reset_password_email`
/// on the backend), picks a new password, and submits to
/// `POST /api/v1/auth/reset-password`.
///
/// The app has no web page or deep-link handler to receive a clickable
/// email link, so the token travels as plain text the user copies into
/// this screen instead — same underlying `secrets.token_urlsafe(32)`
/// value, just a different delivery UX for a mobile-only app.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  /// Only used for the header hint text — the API call itself only needs
  /// the token, not the email.
  final String? email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
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
      await ApiClient.instance.resetPassword(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset — you can log in with your new password now.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(() => _errorMessage = 'Could not reach the server. Check your connection.');
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
              const Text(
                'Reset password',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email == null || widget.email!.isEmpty
                    ? 'Paste the code from your email and choose a new password.'
                    : 'Paste the code we sent to ${widget.email} and choose a new password.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),
              AuthTextField(
                label: 'Reset code',
                hint: 'Paste the code from your email',
                icon: Icons.vpn_key_outlined,
                controller: _tokenController,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter the reset code';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'New password',
                hint: 'Create a new password',
                icon: Icons.lock_outline_rounded,
                controller: _passwordController,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter a new password';
                  if (value.length < 8) return 'At least 8 characters';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: 'Confirm new password',
                hint: 'Re-enter your new password',
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
                title: 'Choose a strong password',
                body: 'At least 8 characters, with an uppercase letter, a lowercase letter, '
                    'a number, and a special character.',
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
                          'Reset password',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
