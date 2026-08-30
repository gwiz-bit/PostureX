import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../../../widgets/icon_badge.dart';
import '../../../../widgets/section_card.dart';
import '../../../../widgets/tag_chip.dart';
import '../../exercises_module.dart';
import 'exercise_detail_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  /// Filter chips used to be four hardcoded categories
  /// (`Strength/Cardio/Core/Mobility`). The library now carries 400+
  /// exercises tagged by muscle group, so the strip is built from whatever
  /// groups the loaded exercises actually have — adding a muscle group is a
  /// DB insert, not an app release.
  static const _allFilter = 'All';

  String _selectedFilter = _allFilter;
  String _query = '';

  final _controller = ExercisesModule.controller();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _iconFor(String? category) {
    switch (category) {
      case 'Cardio':
        return Icons.directions_run_rounded;
      case 'Core':
        return Icons.horizontal_rule_rounded;
      case 'Mobility':
        return Icons.self_improvement_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          // Biggest muscle groups first so the ones with the most exercises
          // are reachable without scrolling the chip strip sideways.
          final counts = <String, int>{};
          for (final e in _controller.exercises) {
            for (final group in e.muscleGroups) {
              counts[group] = (counts[group] ?? 0) + 1;
            }
          }
          final groupNames = counts.keys.toList()
            ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
          final filters = [_allFilter, ...groupNames];

          // A previously picked group can vanish after a reload (exercise
          // deactivated, library re-imported). Fall back to "All" instead of
          // showing an empty list with no chip selected.
          final activeFilter = filters.contains(_selectedFilter) ? _selectedFilter : _allFilter;

          final filtered = _controller.exercises.where((e) {
            if (activeFilter != _allFilter && !e.muscleGroups.contains(activeFilter)) {
              return false;
            }
            if (_query.trim().isNotEmpty &&
                !e.name.toLowerCase().contains(_query.trim().toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: _controller.load,
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
                  onChanged: (v) => setState(() => _query = v),
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
                    itemCount: filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final selected = filter == activeFilter;
                      return _FilterChip(
                        label: filter,
                        selected: selected,
                        onTap: () => setState(() => _selectedFilter = filter),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (_controller.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (_controller.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(children: [
                      Text(_controller.errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _controller.load, child: const Text('Retry')),
                    ]),
                  )
                else if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                        child:
                            Text('No exercises found', style: TextStyle(color: AppColors.textSecondary))),
                  )
                else
                  for (final exercise in filtered) ...[
                    SectionCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(exercise: exercise),
                        ),
                      ),
                      child: Row(
                        children: [
                          IconBadge(icon: _iconFor(exercise.category)),
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
                                // Imported library exercises carry no
                                // category/difficulty (the source only gave a
                                // name and a muscle group), so the muscle
                                // group is the label that always exists.
                                // Wrap, not Row: three chips plus a long
                                // muscle-group name overflow a phone width.
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (exercise.muscleGroups.isNotEmpty)
                                      TagChip(
                                        label: exercise.muscleGroups.first,
                                        color: AppColors.primary,
                                      ),
                                    if (exercise.category != null)
                                      TagChip(label: exercise.category!),
                                    if (exercise.difficulty != null)
                                      TagChip(label: exercise.difficulty!),
                                    // Only ~9 of 400+ exercises can be
                                    // analysed live; flag them so that
                                    // feature is findable at all.
                                    if (exercise.supportsAnalysis)
                                      const TagChip(label: 'Live analysis'),
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
        },
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
