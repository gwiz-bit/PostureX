import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';
import '../widgets/section_card.dart';

class _Routine {
  const _Routine({required this.name, required this.subtitle, required this.icon});

  final String name;
  final String subtitle;
  final IconData icon;
}

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

  static const _routines = [
    _Routine(
      name: 'Full Body Check',
      subtitle: 'Squat · Row · Bench · Plank',
      icon: Icons.accessibility_new_rounded,
    ),
    _Routine(
      name: 'Posture Primer',
      subtitle: 'Cat-Cow · Plank · Lunge',
      icon: Icons.self_improvement_rounded,
    ),
    _Routine(
      name: 'Strength Foundations',
      subtitle: 'Deadlift · OHP · Hip Thrust',
      icon: Icons.fitness_center_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Workout',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 32),
          Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primaryMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Active Workout',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Start a new session or pick exercises\nto begin recording your sets.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text(
                    'Start Empty Workout',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Suggested Routines',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Curated posture-focused workouts',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          for (final routine in _routines) ...[
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () {},
              child: Row(
                children: [
                  IconBadge(icon: routine.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          routine.subtitle,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
