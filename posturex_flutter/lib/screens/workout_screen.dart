import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/exercises_data.dart';

class WorkoutScreen extends StatefulWidget {
  final void Function(String exerciseName) onOpenCamera;
  final VoidCallback onOpenProfile;

  const WorkoutScreen({
    super.key,
    required this.onOpenCamera,
    required this.onOpenProfile,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Difficulty? _difficultyFilter;
  final Set<String> _expandedGroups = {'Chân'};

  bool get _isFiltering => _query.isNotEmpty || _difficultyFilter != null;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bài tập',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                    GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.border,
                        child:
                            Icon(Icons.person, size: 16, color: AppColors.gray),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Tìm bài tập hoặc set tập',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.textSecondary, size: 18),
                    filled: true,
                    fillColor: AppColors.surface,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _DiffChip(
                        label: 'Tất cả',
                        selected: _difficultyFilter == null,
                        onTap: () => setState(() => _difficultyFilter = null),
                      ),
                      const SizedBox(width: 8),
                      _DiffChip(
                        label: 'Mới bắt đầu',
                        selected: _difficultyFilter == Difficulty.beginner,
                        onTap: () => setState(
                            () => _difficultyFilter = Difficulty.beginner),
                      ),
                      const SizedBox(width: 8),
                      _DiffChip(
                        label: 'Trung cấp',
                        selected:
                            _difficultyFilter == Difficulty.intermediate,
                        onTap: () => setState(() =>
                            _difficultyFilter = Difficulty.intermediate),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              itemCount: muscleGroups.length,
              itemBuilder: (context, index) {
                final group = muscleGroups[index];
                final matchesGroupName = _query.isNotEmpty &&
                    group.name.toLowerCase().contains(_query);
                final filteredExercises = group.exercises.where((exercise) {
                  final nameOk = _query.isEmpty ||
                      matchesGroupName ||
                      exercise.name.toLowerCase().contains(_query);
                  final diffOk = _difficultyFilter == null ||
                      exercise.difficulty == _difficultyFilter;
                  return nameOk && diffOk;
                }).toList();

                if (_isFiltering && filteredExercises.isEmpty) {
                  return const SizedBox.shrink();
                }

                final isExpanded = _isFiltering
                    ? true
                    : _expandedGroups.contains(group.name);
                final isFavoriteGroup = group.name == 'Chân';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _isFiltering
                            ? null
                            : () => setState(() {
                                  if (_expandedGroups.contains(group.name)) {
                                    _expandedGroups.remove(group.name);
                                  } else {
                                    _expandedGroups.add(group.name);
                                  }
                                }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(group.icon,
                                    color: AppColors.gray, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(group.name,
                                        style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      isFavoriteGroup
                                          ? '${group.exercises.length} bài tập · hay tập nhất'
                                          : '${group.exercises.length} bài tập',
                                      style: TextStyle(
                                        color: isFavoriteGroup
                                            ? AppColors.teal
                                            : AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 150),
                                child: const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: AppColors.textMuted,
                                    size: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild:
                            const SizedBox(width: double.infinity, height: 0),
                        secondChild: Column(
                          children: filteredExercises
                              .map((exercise) => Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _ExerciseTile(
                                      exercise: exercise,
                                      onTap: () =>
                                          widget.onOpenCamera(exercise.name),
                                    ),
                                  ))
                              .toList(),
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 150),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiffChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.teal : AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.tealDark : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const _ExerciseTile({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBeginner = exercise.difficulty == Difficulty.beginner;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(exercise.icon, color: AppColors.gray, size: 20),
                ),
                Positioned(
                  bottom: -3,
                  right: -3,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: AppColors.teal, size: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(exercise.setsLabel,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isBeginner ? AppColors.tealDark : AppColors.amberDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                exercise.difficultyLabel,
                style: TextStyle(
                  color:
                      isBeginner ? AppColors.tealLight : AppColors.amberLight,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
