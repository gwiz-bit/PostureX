import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'exercises_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';
import 'workout_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _progressKey = GlobalKey<ProgressScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();

  late final _screens = [
    const HomeScreen(),
    const ExercisesScreen(),
    const WorkoutScreen(),
    ProgressScreen(key: _progressKey),
    ProfileScreen(key: _profileKey),
  ];

  static const _items = [
    _NavItemData(icon: Icons.home_rounded, label: 'Home'),
    _NavItemData(icon: Icons.video_library_rounded, label: 'Exercises'),
    _NavItemData(icon: Icons.fitness_center_rounded, label: 'Workout', isLogo: true),
    _NavItemData(icon: Icons.bar_chart_rounded, label: 'Progress'),
    _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
  ];

  /// `IndexedStack` keeps every tab's state alive, so switching to a tab
  /// never re-runs its `initState` — without this, data fetched (or
  /// changed, e.g. a newly logged workout) after a tab's first load would
  /// never show up when coming back to it.
  void _onTabTap(int i) {
    setState(() => _index = i);
    if (i == 3) _progressKey.currentState?.reload();
    if (i == 4) _profileKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    data: _items[i],
                    selected: i == _index,
                    onTap: () => _onTabTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label, this.isLogo = false});

  final IconData icon;
  final String label;
  final bool isLogo;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.selected, required this.onTap});

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: data.isLogo
                  ? AppLogo(size: 22, color: color)
                  : Icon(data.icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
