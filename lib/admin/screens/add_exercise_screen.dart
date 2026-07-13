import 'package:flutter/material.dart';
import '../admin_theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../widgets/common_widgets.dart';
import '../widgets/dialogs.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});
  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String _category = 'Strength';
  String _difficulty = 'Beginner';
  String _exerciseType = 'Standard';
  bool _showError = false;
  bool _isSaving = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _showError = true);
      return;
    }
    setState(() {
      _showError = false;
      _isSaving = true;
    });
    try {
      final exercise = await ApiClient.instance.createAdminExercise(
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        category: _category,
        difficulty: _difficulty,
        exerciseType: _exerciseType,
      );
      if (!mounted) return;
      Navigator.pop(context, exercise);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) showToast(context, 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: adminAppBar('Add New Exercise', 'Exercise library form'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Exercise name (required)')),
          const SizedBox(height: 10),
          TextField(
              controller: _description,
              maxLines: 3,
              style: const TextStyle(color: kInk),
              decoration: adminInput('Description')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: adminInput('Category'),
            items: const [
              DropdownMenuItem(value: 'Strength', child: Text('Strength')),
              DropdownMenuItem(value: 'Cardio', child: Text('Cardio')),
              DropdownMenuItem(value: 'Core', child: Text('Core')),
              DropdownMenuItem(value: 'Mobility', child: Text('Mobility')),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'Strength'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: adminInput('Difficulty'),
            items: const [
              DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'Intermediate', child: Text('Intermediate')),
              DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
            ],
            onChanged: (v) => setState(() => _difficulty = v ?? 'Beginner'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _exerciseType,
            decoration: adminInput('Type'),
            items: const [
              DropdownMenuItem(value: 'Standard', child: Text('Standard (counts reps)')),
              DropdownMenuItem(value: 'Duration', child: Text('Duration (hold pose)')),
            ],
            onChanged: (v) => setState(() => _exerciseType = v ?? 'Standard'),
          ),
          if (_showError)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Exercise name is required', style: TextStyle(color: kRed, fontSize: 12)),
            ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSaving ? 'Saving...' : 'Save to library',
            onPressed: _isSaving ? () {} : _save,
          ),
        ],
      ),
    );
  }
}
