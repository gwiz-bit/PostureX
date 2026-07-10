import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import '../../screens/login_screen.dart';
import 'revenue_screen.dart';
import 'plans_screen.dart';
import 'exercises_screen.dart';
import 'notifications_screen.dart';
import 'users_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showConfirmDialog(
        context, 'Log out?', 'Your session and token will be terminated.');
    if (ok && context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false);
    }
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Statistics & Plans'),
          Row(children: [
            Expanded(
                child: _ModuleCard(
                    icon: Icons.bar_chart,
                    label: 'Revenue',
                    bg: kAmberBg,
                    fg: kAmber,
                    screen: const RevenueScreen())),
            const SizedBox(width: 12),
            Expanded(
                child: _ModuleCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Plans',
                    bg: kBlueBg,
                    fg: kBlue,
                    screen: const PlansScreen())),
          ]),
          const SizedBox(height: 20),
          const SectionLabel('Content'),
          Row(children: [
            Expanded(
                child: _ModuleCard(
                    icon: Icons.fitness_center,
                    label: 'Exercises',
                    bg: kGreenBg,
                    fg: kGreen,
                    screen: const ExercisesScreen())),
            const SizedBox(width: 12),
            Expanded(
                child: _ModuleCard(
                    icon: Icons.notifications_none,
                    label: 'Notifications',
                    bg: kCoralBg,
                    fg: kCoral,
                    screen: const NotificationsScreen())),
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
                    screen: const UsersScreen())),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ]),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final Widget screen;
  const _ModuleCard(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg,
      required this.screen});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
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
