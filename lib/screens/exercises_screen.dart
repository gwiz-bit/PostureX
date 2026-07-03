import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/icon_badge.dart';
import '../widgets/section_card.dart';
import '../widgets/tag_chip.dart';

class _Exercise {
  const _Exercise({
    required this.name,
    required this.icon,
    required this.category,
    required this.level,
  });

  final String name;
  final IconData icon;
  final String category;
  final String level;
}

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  static const _filters = ['All', 'Push', 'Pull', 'Legs', 'Core'];
  String _selectedFilter = 'All';

  static const _exercises = [
    _Exercise(
      name: 'Back Squat',
      icon: Icons.accessibility_new_rounded,
      category: 'Legs',
      level: 'Intermediate',
    ),
    _Exercise(
      name: 'Conventional Deadlift',
      icon: Icons.swap_vert_rounded,
      category: 'Pull',
      level: 'Advanced',
    ),
    _Exercise(
      name: 'Barbell Bench Press',
      icon: Icons.fitness_center_rounded,
      category: 'Push',
      level: 'Intermediate',
    ),
    _Exercise(
      name: 'Standing Overhead Press',
      icon: Icons.arrow_upward_rounded,
      category: 'Push',
      level: 'Intermediate',
    ),
    _Exercise(
      name: 'Bent-Over Barbell Row',
      icon: Icons.arrow_back_rounded,
      category: 'Pull',
      level: 'Intermediate',
    ),
    _Exercise(
      name: 'Forearm Plank',
      icon: Icons.horizontal_rule_rounded,
      category: 'Core',
      level: 'Beginner',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _exercises.where((e) {
      if (_selectedFilter == 'All') return true;
      return e.category == _selectedFilter;
    }).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Exercises',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search exercises',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter == _selectedFilter;
                return _FilterChip(
                  label: filter,
                  selected: selected,
                  onTap: () => setState(() => _selectedFilter = filter),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          for (final exercise in filtered) ...[
            SectionCard(
              padding: const EdgeInsets.all(16),
              onTap: () {},
              child: Row(
                children: [
                  IconBadge(icon: exercise.icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TagChip(label: exercise.category, color: AppColors.primary),
                            const SizedBox(width: 8),
                            TagChip(label: exercise.level),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
