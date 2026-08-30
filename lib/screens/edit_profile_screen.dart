import 'package:flutter/material.dart';

import '../models/profile_limits.dart';
import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../theme/app_theme.dart';
import '../utils/app_locale.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/info_tip_card.dart';

/// Full-screen profile editor — full name, body info (height/weight/age),
/// and an optional password change, all in one place. Replaces the old
/// cramped "Edit profile" AlertDialog (name + password only).
///
/// Body info (age/height/weight) and identity (name/password) live on two
/// different backend tables/endpoints (`UserProfiles` via
/// `PUT /users/me/profile`, `Users` via `PATCH /users/me`), so saving fires
/// up to 2 requests — only for the sections the user actually touched.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with AppLocaleMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: UserSession.name);
  final _heightController = TextEditingController(text: '${UserSession.heightCm}');
  final _weightController = TextEditingController(text: '${UserSession.weightKg}');
  final _ageController = TextEditingController(text: '${UserSession.age}');
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Body info can only be pre-filled from the backend (not `UserSession`,
  /// which only ever holds local onboarding defaults until this loads) —
  /// falls back silently to the current `UserSession` values already
  /// showing in the fields if the fetch fails (offline etc.).
  Future<void> _loadProfile() async {
    try {
      final profile = await ApiClient.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        if (profile.age != null) _ageController.text = '${profile.age}';
        if (profile.heightCm != null) {
          _heightController.text = profile.heightCm!.toStringAsFixed(0);
        }
        if (profile.weightKg != null) {
          _weightController.text = profile.weightKg!.toStringAsFixed(0);
        }
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _newPasswordController.dispose();
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
      final name = _nameController.text.trim();
      final newPassword = _newPasswordController.text;

      if (name != UserSession.name || newPassword.isNotEmpty) {
        final profile = await ApiClient.instance.updateMe(
          fullName: name,
          password: newPassword.isEmpty ? null : newPassword,
        );
        UserSession.name = profile.fullName ?? UserSession.name;
      }

      final height = double.parse(_heightController.text.trim());
      final weight = double.parse(_weightController.text.trim());
      final age = int.parse(_ageController.text.trim());
      await ApiClient.instance.updateProfile(age: age, heightCm: height, weightKg: weight);
      UserSession.heightCm = height.round();
      UserSession.weightKg = weight.round();
      UserSession.age = age;

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
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
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textSecondary,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingProfile)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                AppLocale.t('edit_profile_title'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              AuthTextField(
                label: AppLocale.t('edit_profile_full_name_label'),
                hint: AppLocale.t('edit_profile_full_name_hint'),
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
              Row(
                children: [
                  Expanded(
                    child: AuthTextField(
                      label: AppLocale.t('edit_profile_height_label'),
                      hint: '178',
                      icon: Icons.straighten_rounded,
                      controller: _heightController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: _heightValidator,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthTextField(
                      label: AppLocale.t('edit_profile_weight_label'),
                      hint: '75',
                      icon: Icons.monitor_weight_outlined,
                      controller: _weightController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      validator: _weightValidator,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('edit_profile_age_label'),
                hint: '26',
                icon: Icons.cake_outlined,
                controller: _ageController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final n = int.tryParse((value ?? '').trim());
                  if (n == null) return AppLocale.t('validation_invalid_age');
                  if (n < 1 || n > 120) return AppLocale.t('validation_unrealistic_age');
                  return null;
                },
              ),
              const SizedBox(height: 28),
              Text(
                AppLocale.t('edit_profile_change_password'),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocale.t('edit_profile_password_hint_subtitle'),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AuthTextField(
                label: AppLocale.t('edit_profile_new_password_label'),
                hint: AppLocale.t('edit_profile_new_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _newPasswordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  if (value.length < 8) return AppLocale.t('validation_min_8_chars');
                  return null;
                },
              ),
              const SizedBox(height: 18),
              AuthTextField(
                label: AppLocale.t('edit_profile_confirm_password_label'),
                hint: AppLocale.t('edit_profile_confirm_password_hint'),
                icon: Icons.lock_outline_rounded,
                controller: _confirmPasswordController,
                enabled: !_isSubmitting,
                isPassword: true,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (_newPasswordController.text.isEmpty) return null;
                  if (value != _newPasswordController.text) return AppLocale.t('validation_passwords_mismatch');
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
                          AppLocale.t('edit_profile_save'),
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

  String? _heightValidator(String? value) {
    final n = double.tryParse((value ?? '').trim());
    if (n == null) return 'Enter a valid number';
    if (n < ProfileLimits.heightCmMin || n > ProfileLimits.heightCmMax) {
      return 'Enter a height between ${ProfileLimits.heightCmMin}-${ProfileLimits.heightCmMax} cm';
    }
    return null;
  }

  String? _weightValidator(String? value) {
    final n = double.tryParse((value ?? '').trim());
    if (n == null) return 'Enter a valid number';
    if (n < ProfileLimits.weightKgMin || n > ProfileLimits.weightKgMax) {
      return 'Enter a weight between ${ProfileLimits.weightKgMin}-${ProfileLimits.weightKgMax} kg';
    }
    return null;
  }
}
