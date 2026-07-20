import 'package:flutter/material.dart';

import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';

/// 4-week (Sun-Sat rows) calendar grid for a [WorkoutPlan]. Workout days are
/// highlighted; tapping any day opens a sheet with that day's session, where
/// it can be created, edited, or deleted — [onDayChanged] carries the result
/// back up so the caller can swap it into its `WorkoutPlan`.
class PlanCalendar extends StatelessWidget {
  const PlanCalendar({super.key, required this.plan, required this.onDayChanged});

  final WorkoutPlan plan;
  final ValueChanged<DayPlan> onDayChanged;

  static const _weekdayHeaders = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
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
                        onTap: () => _showDayDetail(context, day),
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showDayDetail(BuildContext context, DayPlan day) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayDetailSheet(day: day, onSave: onDayChanged),
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

/// One exercise row while editing — holds its own controllers so text state
/// survives rebuilds without re-reading from [DayPlan] on every keystroke.
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
  const _DayDetailSheet({required this.day, required this.onSave});

  final DayPlan day;
  final ValueChanged<DayPlan> onSave;

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

  bool _isEditing = false;
  late TextEditingController _sessionNameController;
  late List<_ExerciseDraft> _exercises;

  @override
  void initState() {
    super.initState();
    _sessionNameController = TextEditingController(
      text: widget.day.isRestDay ? '' : widget.day.sessionName,
    );
    _exercises = [
      for (final exercise in widget.day.exercises)
        _ExerciseDraft(name: exercise.name, setsReps: exercise.setsReps),
    ];
  }

  @override
  void dispose() {
    _sessionNameController.dispose();
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  String get _dateLabel {
    final date = widget.day.date;
    return '${_weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
  }

  void _startEditing() => setState(() => _isEditing = true);

  void _addExerciseRow() => setState(() => _exercises.add(_ExerciseDraft()));

  void _removeExerciseRow(int index) => setState(() {
        _exercises.removeAt(index).dispose();
      });

  void _save() {
    final name = _sessionNameController.text.trim();
    final exercises = [
      for (final draft in _exercises)
        if (draft.nameController.text.trim().isNotEmpty)
          PlannedExercise(
            name: draft.nameController.text.trim(),
            setsReps: draft.setsRepsController.text.trim().isEmpty
                ? '3 × 10'
                : draft.setsRepsController.text.trim(),
          ),
    ];

    if (exercises.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a session name and at least one exercise.')),
      );
      return;
    }

    widget.onSave(DayPlan(
      date: widget.day.date,
      sessionName: name,
      exercises: exercises,
    ));
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Delete this session?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This day will become a rest day.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    widget.onSave(DayPlan(date: widget.day.date, sessionName: 'Rest', exercises: const []));
    if (mounted) Navigator.of(context).pop();
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
              Text(
                _dateLabel,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _isEditing ? _buildEditHeader() : _buildViewHeader(),
              const SizedBox(height: 20),
              if (_isEditing) ..._buildEditBody() else ..._buildViewBody(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            widget.day.isRestDay ? 'Rest Day' : widget.day.sessionName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (!widget.day.isRestDay) ...[
          IconButton(
            onPressed: _startEditing,
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            tooltip: 'Edit session',
          ),
          IconButton(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete session',
          ),
        ],
      ],
    );
  }

  Widget _buildEditHeader() {
    return TextField(
      controller: _sessionNameController,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Session name (e.g. Push Day)',
        hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w500),
        isDense: true,
        border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
      ),
    );
  }

  List<Widget> _buildViewBody() {
    if (widget.day.isRestDay) {
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
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _startEditing,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a session'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ];
    }

    final exercises = widget.day.exercises;
    return [
      for (var i = 0; i < exercises.length; i++) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const AppLogo(size: 18, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  exercises[i].name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                exercises[i].setsReps,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (i != exercises.length - 1) const Divider(color: AppColors.border, height: 1),
      ],
    ];
  }

  List<Widget> _buildEditBody() {
    return [
      for (var i = 0; i < _exercises.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _exercises[i].nameController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Exercise name',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _exercises[i].setsRepsController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 4 × 10',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeExerciseRow(i),
                icon: const Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 20),
              ),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: _addExerciseRow,
        icon: const Icon(Icons.add_rounded, color: AppColors.primary),
        label: const Text('Add exercise', style: TextStyle(color: AppColors.primary)),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    ];
  }
}
