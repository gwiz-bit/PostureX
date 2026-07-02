import 'package:flutter/material.dart';

enum Difficulty { beginner, intermediate }

class Exercise {
  final String name;
  final String setsLabel;
  final Difficulty difficulty;
  final IconData icon;

  const Exercise({
    required this.name,
    required this.setsLabel,
    required this.difficulty,
    required this.icon,
  });

  String get difficultyLabel =>
      difficulty == Difficulty.beginner ? 'Mới bắt đầu' : 'Trung cấp';
}

class MuscleGroup {
  final String name;
  final IconData icon;
  final List<Exercise> exercises;

  const MuscleGroup({
    required this.name,
    required this.icon,
    required this.exercises,
  });
}

const List<MuscleGroup> muscleGroups = [
  MuscleGroup(
    name: 'Chân',
    icon: Icons.directions_run,
    exercises: [
      Exercise(
        name: 'Squat',
        setsLabel: '3 hiệp x 12',
        difficulty: Difficulty.beginner,
        icon: Icons.accessibility_new,
      ),
      Exercise(
        name: 'Lunge (chùng chân)',
        setsLabel: '3 hiệp x 10 mỗi bên',
        difficulty: Difficulty.intermediate,
        icon: Icons.directions_walk,
      ),
    ],
  ),
  MuscleGroup(
    name: 'Ngực và tay',
    icon: Icons.fitness_center,
    exercises: [
      Exercise(
        name: 'Push-up',
        setsLabel: '3 hiệp x 15',
        difficulty: Difficulty.beginner,
        icon: Icons.swap_vert,
      ),
      Exercise(
        name: 'Hít đẩy vai',
        setsLabel: '3 hiệp x 10',
        difficulty: Difficulty.intermediate,
        icon: Icons.arrow_upward,
      ),
    ],
  ),
  MuscleGroup(
    name: 'Lưng và bụng',
    icon: Icons.self_improvement,
    exercises: [
      Exercise(
        name: 'Plank',
        setsLabel: '3 hiệp x 30 giây',
        difficulty: Difficulty.beginner,
        icon: Icons.remove,
      ),
      Exercise(
        name: 'Superman (nâng lưng)',
        setsLabel: '3 hiệp x 12',
        difficulty: Difficulty.intermediate,
        icon: Icons.north_east,
      ),
    ],
  ),
];
