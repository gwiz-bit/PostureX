import 'package:flutter/material.dart';

import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// 4-week (Sun-Sat rows) calendar grid for a [WorkoutPlan]. Workout days are
/// highlighted; tapping any day opens a sheet with that day's session, which
/// can be edited in place.
class PlanCalendar extends StatefulWidget {
  const PlanCalendar({super.key, required this.plan});

  final WorkoutPlan plan;

  @override
  State<PlanCalendar> createState() => _PlanCalendarState();
}

class _PlanCalendarState extends State<PlanCalendar> {
  static const _weekdayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _showDayDetail(DayPlan day) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(plan: widget.plan, day: day),
    );
    // The sheet mutates `widget.plan.days` in place — a rebuild is enough to
    // pick up the change, no new data to fetch.
    if (changed == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final plan = widget.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 26),
            for (final header in _weekdayHeaders)
              Expanded(
                child: Center(
                  child: Text(
                    header,
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var week = 0; week < WorkoutPlan.totalWeeks; week++) ...[
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  'W${week + 1}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final day = plan.days[week * 7 + d];
                      return _DayCell(
                        day: day,
                        isToday: _isSameDay(day.date, today),
                        onTap: () => _showDayDetail(day),
                      );
                    },
                  ),
                ),
            ],
          ),
          if (week != WorkoutPlan.totalWeeks - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.isToday, required this.onTap});

  final DayPlan day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRest = day.isRestDay;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isRest ? Colors.transparent : AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(10),
              border: isToday ? Border.all(color: AppColors.primary, width: 1.5) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.date.day}',
              style: TextStyle(
                color: isRest ? AppColors.textTertiary : AppColors.primary,
                fontSize: 13,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One exercise row while editing — holds its own controllers so text field
/// state survives rebuilds triggered by adding/removing sibling rows.
class _ExerciseDraft {
  _ExerciseDraft({String name = '', String setsReps = ''})
      : nameController = TextEditingController(text: name),
        setsRepsController = TextEditingController(text: setsReps);

  final TextEditingController nameController;
  final TextEditingController setsRepsController;

  void dispose() {
    nameController.dispose();
    setsRepsController.dispose();
  }
}

class _DayDetailSheet extends StatefulWidget {
  const _DayDetailSheet({required this.plan, required this.day});

  final WorkoutPlan plan;
  final DayPlan day;

  @override
  State<_DayDetailSheet> createState() => _DayDetailSheetState();
}

class _DayDetailSheetState extends State<_DayDetailSheet> {
  static const _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late DayPlan _day = widget.day;
  bool _editing = false;
  late TextEditingController _sessionNameController;
  List<_ExerciseDraft> _drafts = [];
  String? _error;

  String get _dateLabel {
    final date = _day.date;
    return '${_weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
  }

  void _startEditing() {
    _sessionNameController = TextEditingController(
      text: _day.isRestDay ? '' : _day.sessionName,
    );
    _drafts = [
      for (final exercise in _day.exercises)
        _ExerciseDraft(name: exercise.name, setsReps: exercise.setsReps),
    ];
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    _sessionNameController.dispose();
    setState(() {
      _editing = false;
      _error = null;
    });
  }

  void _addExerciseRow() {
    setState(() => _drafts.add(_ExerciseDraft(setsReps: '3 × 10')));
  }

  void _removeExerciseRow(int index) {
    setState(() => _drafts.removeAt(index).dispose());
  }

  void _save() {
    final exercises = [
      for (final draft in _drafts)
        if (draft.nameController.text.trim().isNotEmpty)
          PlannedExercise(
            name: draft.nameController.text.trim(),
            setsReps: draft.setsRepsController.text.trim().isEmpty
                ? '3 × 10'
                : draft.setsRepsController.text.trim(),
          ),
    ];
    if (exercises.isNotEmpty && _sessionNameController.text.trim().isEmpty) {
      setState(() => _error = 'Give this session a name.');
      return;
    }

    final sessionName =
        exercises.isEmpty ? 'Rest' : _sessionNameController.text.trim();
    widget.plan.updateDay(_day.date, sessionName, exercises);

    for (final draft in _drafts) {
      draft.dispose();
    }
    _sessionNameController.dispose();

    setState(() {
      _day = DayPlan(date: _day.date, sessionName: sessionName, exercises: exercises);
      _editing = false;
      _error = null;
    });
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    if (_editing) {
      for (final draft in _drafts) {
        draft.dispose();
      }
      _sessionNameController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!_editing)
                          Text(
                            _day.sessionName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_editing)
                    IconButton(
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                      tooltip: 'Edit exercises',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_editing) ..._buildEditor() else ..._buildView(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildView() {
    if (_day.isRestDay) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.self_improvement_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Take it easy — recover, stretch, and get ready for your next session.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._buildNutritionTip(),
      ];
    }
    return [
      for (var i = 0; i < _day.exercises.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const AppLogo(size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _day.exercises[i].name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _day.exercises[i].setsReps,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (i != _day.exercises.length - 1) const Divider(color: AppColors.border, height: 1),
      ],
      const SizedBox(height: 8),
      ..._buildNutritionTip(),
    ];
  }

  List<Widget> _buildNutritionTip() {
    final tip = _day.nutritionTip;
    if (tip == null || tip.trim().isEmpty) return const [];
    return [
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tip,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _buildEditor() {
    return [
      TextField(
        controller: _sessionNameController,
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: 'Session name',
          hintText: 'e.g. Full Body Strength',
          hintStyle: TextStyle(color: AppColors.textTertiary),
          labelStyle: TextStyle(color: AppColors.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 14),
      for (var i = 0; i < _drafts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _drafts[i].nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _drafts[i].setsRepsController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Sets × reps',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeExerciseRow(i),
                icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: _addExerciseRow,
        icon: const Icon(Icons.add_rounded, color: AppColors.primary),
        label: const Text('Add exercise', style: TextStyle(color: AppColors.primary)),
      ),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancelEditing,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ];
  }
}
