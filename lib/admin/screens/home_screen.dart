import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../models/user_session.dart';
import '../models/admin_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import '../../screens/login_screen.dart';
import 'workouts_screen.dart';
import 'videos_screen.dart';
import 'ai_config_screen.dart';
import 'users_screen.dart';
import 'exercises_screen.dart';
import 'plans_screen.dart';
import 'revenue_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SystemStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ApiClient.instance.fetchAdminStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } on ApiException catch (_) {
      // Dashboard tiles below still work standalone — silently keep stats blank.
    } catch (_) {
      // Same: no connectivity shouldn't block navigation to the modules.
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
        context, 'Log out?', 'Your session and token will be terminated.');
    if (ok && context.mounted) {
      UserSession.logOut();
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false);
    }
  }

  Future<void> _openModule(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text('PX',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.primary))),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PostureX Admin',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('System management',
                    style: TextStyle(fontSize: 12, color: kSubtitle)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Log out',
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionLabel('Overview'),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_stats != null) ...[
              Row(children: [
                Expanded(
                    child: MetricCard(label: 'Total users', value: '${_stats!.totalUsers}')),
                const SizedBox(width: 12),
                Expanded(
                    child: MetricCard(label: 'Active users', value: '${_stats!.activeUsers}')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: MetricCard(label: 'Workouts logged', value: '${_stats!.totalWorkouts}')),
                const SizedBox(width: 12),
                Expanded(child: MetricCard(label: 'Videos uploaded', value: '${_stats!.totalVideos}')),
              ]),
            ],
            const SizedBox(height: 20),
            const SectionLabel('Content'),
            Row(children: [
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.fitness_center,
                      label: 'Workouts',
                      bg: kGreenBg,
                      fg: kGreen,
                      onTap: () => _openModule(const WorkoutsScreen()))),
              const SizedBox(width: 12),
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.videocam_outlined,
                      label: 'Videos',
                      bg: kAmberBg,
                      fg: kAmber,
                      onTap: () => _openModule(const VideosScreen()))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.tune,
                      label: 'AI Config',
                      bg: kPurpleBg,
                      fg: kPurple,
                      onTap: () => _openModule(const AIConfigScreen()))),
              const SizedBox(width: 12),
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.campaign_outlined,
                      label: 'Notifications',
                      bg: kBlueBg,
                      fg: kBlue,
                      onTap: () => _openModule(const NotificationsScreen()))),
            ]),
            const SizedBox(height: 20),
            const SectionLabel('Statistics & Plans'),
            Row(children: [
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.payments_outlined,
                      label: 'Revenue',
                      bg: kGreenBg,
                      fg: kGreen,
                      onTap: () => _openModule(const RevenueScreen()))),
              const SizedBox(width: 12),
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Plans',
                      bg: kPurpleBg,
                      fg: kPurple,
                      onTap: () => _openModule(const PlansScreen()))),
            ]),
            const SizedBox(height: 20),
            const SectionLabel('Users'),
            Row(children: [
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.group_outlined,
                      label: 'Users',
                      bg: kPurpleBg,
                      fg: kPurple,
                      onTap: () => _openModule(const UsersScreen()))),
              const SizedBox(width: 12),
              Expanded(
                  child: _ModuleCard(
                      icon: Icons.sports_gymnastics_outlined,
                      label: 'Exercises',
                      bg: kGreenBg,
                      fg: kGreen,
                      onTap: () => _openModule(const ExercisesScreen()))),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _ModuleCard(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: fg, size: 26),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
          ],
        ),
      ),
    );
  }
}
