import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/google_auth_service.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../utils/app_locale.dart';
import '../widgets/section_card.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/subscription/presentation/screens/subscription_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    AppLocale.notifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.notifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocale.t('settings'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // ── Language ──────────────────────────────────────────────────
          Text(
            AppLocale.t('language'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _LangOption(
                  label: AppLocale.t('english'),
                  selected: AppLocale.current == AppLocale.en,
                  onTap: () => AppLocale.setLanguage(AppLocale.en),
                ),
                const SizedBox(width: 10),
                _LangOption(
                  label: AppLocale.t('vietnamese'),
                  selected: AppLocale.current == AppLocale.vi,
                  onTap: () => AppLocale.setLanguage(AppLocale.vi),
                ),
              ],
            ),
          ),

          // ── Premium ───────────────────────────────────────────────────
          const SizedBox(height: 28),
          Text(
            AppLocale.t('premium'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    AppLocale.t('subscribe'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    AppLocale.t('privacy_policy'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),

          // ── Account ───────────────────────────────────────────────────
          const SizedBox(height: 28),
          Text(
            AppLocale.t('account'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () => _confirmDeleteAccount(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever_rounded,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    AppLocale.t('delete_account'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () => _confirmLogOut(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.logout_rounded,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    AppLocale.t('log_out'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocale.t('log_out_title'),
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(AppLocale.t('log_out_body'),
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary),
            child: Text(AppLocale.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(AppLocale.t('log_out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await TokenStorage.clear();
    } catch (_) {}
    await GoogleAuthService.disconnect();
    UserSession.logOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(AppLocale.t('delete_account_title'),
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(AppLocale.t('delete_account_body'),
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary),
            child: Text(AppLocale.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(AppLocale.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ApiClient.instance.deleteAccount();
    } catch (_) {}
    try {
      await TokenStorage.clear();
    } catch (_) {}
    await GoogleAuthService.disconnect();
    UserSession.logOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary,
                fontSize: 14,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
