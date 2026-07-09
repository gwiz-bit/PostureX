import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/exercise.dart';
import '../services/mock_data_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';
import 'add_exercise_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});
  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final _data = MockDataService.instance;

  (Color, Color) _statusColors(ExerciseStatus s) {
    switch (s) {
      case ExerciseStatus.published:
        return (kGreenBg, kGreen);
      case ExerciseStatus.hidden:
        return (kRedBg, kRed);
      case ExerciseStatus.draft:
        return (kGrayBg, kGrayFg);
    }
  }

  Future<void> _hide(Exercise ex) async {
    final ok = await showConfirmDialog(context, 'Hide ${ex.name}?',
        'Soft delete: exercise hidden from app, user training history retained.');
    if (ok) {
      setState(() => ex.status = ExerciseStatus.hidden);
      if (mounted) showToast(context, '${ex.name} hidden');
    }
  }

  Future<void> _add() async {
    final created = await Navigator.push<Exercise>(
        context, MaterialPageRoute(builder: (_) => const AddExerciseScreen()));
    if (created != null) {
      setState(() => _data.exercises.add(created));
      if (mounted) showToast(context, 'Saved to DB');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _data.exercises;
    return Scaffold(
      appBar: adminAppBar('Exercise Management', '${items.length} exercises',
          actions: [
            IconButton(onPressed: _add, icon: const Icon(Icons.add))
          ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              style: const TextStyle(color: kInk),
              decoration: adminInput('Search exercises...')),
          const SizedBox(height: 12),
          ListCard(
            rows: items.map((ex) {
              final (bg, fg) = _statusColors(ex.status);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  const CircleAvatar(
                      radius: 17,
                      backgroundColor: kGreenBg,
                      child: Icon(Icons.fitness_center,
                          size: 17, color: kGreen)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ex.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: kInk)),
                          Text(ex.detail,
                              style: const TextStyle(
                                  fontSize: 11, color: kMuted)),
                        ]),
                  ),
                  StatusBadge(ex.status.label, bg, fg),
                  const SizedBox(width: 8),
                  InkWell(
                      onTap: () => _hide(ex),
                      child: const Icon(Icons.visibility_off_outlined,
                          size: 19, color: kRed)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
