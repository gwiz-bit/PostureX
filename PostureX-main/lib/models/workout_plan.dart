/// A single planned exercise within a day's session.
class PlannedExercise {
  const PlannedExercise({required this.name, required this.setsReps});

  final String name;
  final String setsReps;
}

/// One day of a [WorkoutPlan] — either a training session or a rest day
/// (when [exercises] is empty).
class DayPlan {
  const DayPlan({required this.date, required this.sessionName, required this.exercises});

  final DateTime date;
  final String sessionName;
  final List<PlannedExercise> exercises;

  bool get isRestDay => exercises.isEmpty;
}

class _SessionTemplate {
  const _SessionTemplate(this.name, this.exercises);

  final String name;
  final List<String> exercises;
}

const _fullBody = _SessionTemplate('Full Body Strength', [
  'Back Squat',
  'Barbell Bench Press',
  'Bent-Over Barbell Row',
  'Forearm Plank',
]);
const _push = _SessionTemplate('Upper Body — Push', [
  'Barbell Bench Press',
  'Standing Overhead Press',
  'Forearm Plank',
]);
const _pull = _SessionTemplate('Upper Body — Pull', [
  'Conventional Deadlift',
  'Bent-Over Barbell Row',
  'Forearm Plank',
]);
const _lower = _SessionTemplate('Lower Body & Core', [
  'Back Squat',
  'Conventional Deadlift',
  'Forearm Plank',
]);

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// A 4-week (28 day) training block, generated from the goals collected
/// during onboarding, and shown as a calendar on Home.
class WorkoutPlan {
  const WorkoutPlan({required this.startDate, required this.days});

  static const totalWeeks = 4;

  /// The Sunday that begins week 1 — the grid always shows full weeks.
  final DateTime startDate;

  /// 28 entries, one per day, in chronological order.
  final List<DayPlan> days;

  DateTime get endDate => days.last.date;

  DayPlan? planFor(DateTime date) {
    final target = _dateOnly(date);
    for (final day in days) {
      if (_dateOnly(day.date) == target) return day;
    }
    return null;
  }

  /// 0-based week index (0..3) for a date within the plan, clamped to range.
  int weekIndexFor(DateTime date) {
    final diff = _dateOnly(date).difference(startDate).inDays;
    return diff.clamp(0, days.length - 1) ~/ 7;
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static WorkoutPlan generate({
    required Set<String> workoutDays,
    required int weeklyGoal,
    required Set<String> focusAreas,
    required String fitnessLevel,
    DateTime? referenceDate,
  }) {
    final today = _dateOnly(referenceDate ?? DateTime.now());
    // weekday: Mon=1..Sun=7 — step back to the most recent Sunday so every
    // week in the grid is a full Sun-Sat row.
    final start = today.subtract(Duration(days: today.weekday % 7));

    final activeDays = workoutDays.isNotEmpty ? workoutDays : _fallbackDays(weeklyGoal);
    final templates = _templatesFor(focusAreas);
    final sets = switch (fitnessLevel) {
      'Beginner' => 3,
      'Advanced' => 5,
      _ => 4,
    };

    var templateIndex = 0;
    final days = <DayPlan>[];
    for (var i = 0; i < 28; i++) {
      final date = start.add(Duration(days: i));
      final label = _weekdayLabels[date.weekday - 1];
      if (activeDays.contains(label)) {
        final template = templates[templateIndex % templates.length];
        templateIndex++;
        days.add(DayPlan(
          date: date,
          sessionName: template.name,
          exercises: [
            for (final exercise in template.exercises)
              PlannedExercise(name: exercise, setsReps: '$sets × 10'),
          ],
        ));
      } else {
        days.add(DayPlan(date: date, sessionName: 'Rest', exercises: const []));
      }
    }

    return WorkoutPlan(startDate: start, days: days);
  }

  static Set<String> _fallbackDays(int weeklyGoal) {
    const patterns = {
      1: ['Wed'],
      2: ['Tue', 'Fri'],
      3: ['Mon', 'Wed', 'Fri'],
      4: ['Mon', 'Tue', 'Thu', 'Fri'],
      5: ['Mon', 'Tue', 'Wed', 'Fri', 'Sat'],
      6: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
      7: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    };
    return patterns[weeklyGoal.clamp(1, 7)]!.toSet();
  }

  static List<_SessionTemplate> _templatesFor(Set<String> focusAreas) {
    if (focusAreas.isEmpty || focusAreas.contains('Full body')) {
      return const [_fullBody, _lower, _push, _pull];
    }
    final templates = <_SessionTemplate>[];
    if (focusAreas.any(const {'Chest', 'Shoulder', 'Arm'}.contains)) templates.add(_push);
    if (focusAreas.any(const {'Back', 'Arm'}.contains)) templates.add(_pull);
    if (focusAreas.any(const {'Leg', 'Glutes'}.contains)) templates.add(_lower);
    if (focusAreas.contains('Abs') || templates.isEmpty) templates.add(_fullBody);
    return templates;
  }
}
