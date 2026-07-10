import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../models/exercise.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});
  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _name = TextEditingController();
  final _group = TextEditingController();
  final _video = TextEditingController();
  final _ai = TextEditingController();
  bool _showError = false;

  void _save() {
    if (_name.text.trim().isEmpty || _video.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(
      context,
      Exercise(
        name: _name.text.trim(),
        detail: _group.text.trim().isEmpty ? 'New exercise' : _group.text.trim(),
        status: ExerciseStatus.draft,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Add Exercise', 'Exercise form'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Exercise name (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _group,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Muscle group, difficulty')),
          const SizedBox(height: 10),
          TextField(
              controller: _video,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Demo video link (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _ai,
              style: const TextStyle(color: kInk),
              decoration: adminInput('AI config: joint angle threshold, posture errors')),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Missing required fields — name and video link',
                  style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Save to DB', onPressed: _save),
        ],
      ),
    );
  }
}
