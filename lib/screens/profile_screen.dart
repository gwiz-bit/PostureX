import 'package:flutter/material.dart';

import '../models/user_session.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/token_storage.dart';
import '../theme/app_theme.dart';
import '../utils/workout_stats.dart';
import '../widgets/section_card.dart';
import '../widgets/tag_chip.dart';
import 'login_screen.dart';
import 'subscription_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  WorkoutStats _stats = const WorkoutStats(
    sessionCount: 0,
    totalReps: 0,
    averageAccuracy: null,
    bestAccuracy: null,
  );
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Public so [MainShell] can force a fresh fetch when this tab is
  /// selected — `IndexedStack` keeps this widget's state alive across tab
  /// switches, so [initState] only runs once and a workout logged after
  /// the first load would otherwise never show up here.
  Future<void> reload() => _load();

  Future<void> _load() async {
    try {
      final profile = await ApiClient.instance.fetchMe();
      if (profile.fullName != null && profile.fullName!.trim().isNotEmpty) {
        UserSession.name = profile.fullName!;
      }
      final workouts = await ApiClient.instance.fetchWorkouts();
      if (!mounted) return;
      setState(() {
        _stats = computeStats(workouts);
        _isLoading = false;
      });
    } catch (_) {
      // Offline or session expired — keep showing whatever UserSession
      // already holds locally rather than blocking the screen.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 44),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      UserSession.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editProfile(context),
                      icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  UserSession.fitnessLevel.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: _isLoading ? '—' : '${_stats.sessionCount}',
                  label: 'Sessions',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: _isLoading ? '—' : '${_stats.totalReps}',
                  label: 'Reps',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  value: _isLoading || _stats.averageAccuracy == null
                      ? '—'
                      : '${_stats.averageAccuracy!.round()}',
                  label: 'Posture',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Personal Info',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.straighten_rounded,
                  label: 'Height',
                  value: '${UserSession.heightCm} cm',
                ),
                const Divider(color: AppColors.border, height: 1),
                _InfoRow(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: '${UserSession.weightKg} kg',
                ),
                const Divider(color: AppColors.border, height: 1),
                _InfoRow(icon: Icons.cake_outlined, label: 'Age', value: '${UserSession.age} yrs'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Training Preferences',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.flag_outlined,
                  label: 'Weekly Goal',
                  value: '${UserSession.weeklyGoal} sessions',
                ),
                const Divider(color: AppColors.border, height: 1),
                _InfoRow(
                  icon: Icons.bolt_outlined,
                  label: 'Experience',
                  value: UserSession.fitnessLevel,
                ),
                const Divider(color: AppColors.border, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.track_changes_outlined, color: AppColors.textSecondary, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Focus Areas',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const Spacer(),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final area in UserSession.focusAreas)
                            TagChip(label: area, color: AppColors.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Premium',
            style: TextStyle(
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
                  const Icon(Icons.workspace_premium_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'Subscribe',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () => _confirmLogOut(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Log out',
                    style: TextStyle(
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
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final nameController = TextEditingController(text: UserSession.name);
    final passwordController = TextEditingController();
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit profile',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'New password (optional)',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final profile = await ApiClient.instance.updateMe(
                    fullName: nameController.text.trim(),
                    password: passwordController.text.isEmpty ? null : passwordController.text,
                  );
                  UserSession.name = profile.fullName ?? UserSession.name;
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop(true);
                } on ApiException catch (e) {
                  setDialogState(() => errorText = e.message);
                } catch (_) {
                  setDialogState(() => errorText = 'Could not reach the server.');
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) setState(() {});
  }

  Future<void> _confirmLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "You'll need to log in again to access your posture data.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await TokenStorage.clear();
    } catch (_) {
      // Best-effort — still log the user out locally either way.
    }
    UserSession.logOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
