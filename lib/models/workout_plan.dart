import 'dart:math';

/// Minimal exercise info needed to build a personalized plan from server data.
/// Created in [PlanGeneratingScreen] from the full exercise list returned by
/// the server — keeps [WorkoutPlan] free of any network-layer imports.
typedef ServerExercise = ({
  String name,
  List<String> muscleGroups,
  String? difficulty,
  bool supportsAnalysis,
});


/// A single planned exercise within a day's session.
class PlannedExercise {
  const PlannedExercise({required this.name, required this.setsReps});

  final String name;
  final String setsReps;
}

/// One day of a [WorkoutPlan] — either a training session or a rest day
/// (when [exercises] is empty).
class DayPlan {
  const DayPlan({
    required this.date,
    required this.sessionName,
    required this.exercises,
    this.nutritionTip,
  });

  final DateTime date;
  final String sessionName;
  final List<PlannedExercise> exercises;

  /// Set only for days generated/refreshed by the AI Coach's plan generator
  /// (see [WorkoutPlan.applyAiWeek]) — `null` for the static onboarding
  /// templates, which don't have per-day nutrition guidance.
  final String? nutritionTip;

  bool get isRestDay => exercises.isEmpty;
}

// Static fallback templates — used when server exercise list is unavailable.
class _SessionTemplate {
  const _SessionTemplate(this.name, this.exercises);

  final String name;
  final List<String> exercises;
}

const _fullBody = _SessionTemplate('Full Body Strength', [
  'Barbell Squat',
  'Barbell Bench Press',
  'Barbell Bent Over Row',
  'Plank',
]);
const _push = _SessionTemplate('Upper Body — Push', [
  'Barbell Bench Press',
  'Barbell Overhead Press',
  'Plank',
]);
const _pull = _SessionTemplate('Upper Body — Pull', [
  'Barbell Deadlift',
  'Barbell Bent Over Row',
  'Plank',
]);
const _lower = _SessionTemplate('Lower Body & Core', [
  'Barbell Squat',
  'Barbell Deadlift',
  'Plank',
]);

// Muscle-group keyword lists for dynamic exercise selection.
const _pushKws = <String>['chest', 'pectoral', 'shoulder', 'deltoid', 'delt', 'tricep'];
const _pullKws = <String>['back', 'lat', 'trap', 'rhomboid', 'bicep', 'rear delt'];
const _lowerKws = <String>['leg', 'quad', 'hamstring', 'calf', 'calves', 'glute', 'hip'];
const _coreKws = <String>['abs', 'core', 'abdominal', 'oblique'];

/// Session definition for the dynamic (server-data) path:
/// a display name + list of (muscle keywords, count to pick) pairs.
class _DynSession {
  const _DynSession(this.name, this.picks);

  final String name;
  final List<(List<String>, int)> picks;
}

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

  /// Replaces the session name + exercise list for the day matching [date].
  void updateDay(
    DateTime date,
    String sessionName,
    List<PlannedExercise> exercises, {
    String? nutritionTip,
  }) {
    final target = _dateOnly(date);
    final index = days.indexWhere((d) => _dateOnly(d.date) == target);
    if (index == -1) return;
    days[index] = DayPlan(
      date: days[index].date,
      sessionName: exercises.isEmpty ? 'Rest' : sessionName,
      exercises: exercises,
      nutritionTip: nutritionTip ?? days[index].nutritionTip,
    );
  }

  /// Applies a 7-day (Mon..Sun) AI-generated plan across every week of this
  /// 4-week grid, matching each day by weekday.
  void applyAiWeek(List<({String dayLabel, String sessionName, bool isRest, List<PlannedExercise> exercises, String nutritionTip})> week) {
    final byLabel = {for (final d in week) d.dayLabel: d};
    for (var i = 0; i < days.length; i++) {
      final label = _weekdayLabels[days[i].date.weekday - 1];
      final aiDay = byLabel[label];
      if (aiDay == null) continue;
      days[i] = DayPlan(
        date: days[i].date,
        sessionName: aiDay.isRest ? 'Rest' : aiDay.sessionName,
        exercises: aiDay.isRest ? const [] : aiDay.exercises,
        nutritionTip: aiDay.nutritionTip,
      );
    }
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
    Set<String> equipment = const {},
    Set<String> goals = const {},
    Set<String> healthIssues = const {},
    List<ServerExercise>? serverExercises,
    DateTime? referenceDate,
  }) {
    final today = _dateOnly(referenceDate ?? DateTime.now());
    // weekday: Mon=1..Sun=7 — step back to the most recent Sunday so every
    // week in the grid is a full Sun-Sat row.
    final start = today.subtract(Duration(days: today.weekday % 7));

    final activeDays = workoutDays.isNotEmpty ? workoutDays : _fallbackDays(weeklyGoal);

    // Post-injury recovery forces Beginner difficulty regardless of self-reported level.
    final effectiveLevel = healthIssues.contains('Post-injury recovery')
        ? 'Beginner'
        : fitnessLevel;

    final setsReps = _setsRepsFor(goals, effectiveLevel);
    final days = <DayPlan>[];

    if (serverExercises != null && serverExercises.isNotEmpty) {
      // Dynamic path: each session picks random exercises from the filtered
      // pool; exercises already used in earlier sessions are excluded so the
      // same exercise never appears twice across the whole 4-week plan.
      final rng = Random();
      final used = <String>{};

      final filtered = serverExercises
          .where((e) => _matchesEquipment(e, equipment))
          .where((e) => !_isExcludedByHealthIssues(e, healthIssues))
          .toList();

      final sessions = _dynSessionsFor(focusAreas);
      var si = 0;

      for (var i = 0; i < 28; i++) {
        final date = start.add(Duration(days: i));
        final label = _weekdayLabels[date.weekday - 1];
        if (activeDays.contains(label)) {
          final sess = sessions[si % sessions.length];
          si++;
          final names = _buildSessionNames(filtered, sess, effectiveLevel, used, rng);
          used.addAll(names);
          days.add(DayPlan(
            date: date,
            sessionName: sess.name,
            exercises: [for (final n in names) PlannedExercise(name: n, setsReps: setsReps)],
          ));
        } else {
          days.add(DayPlan(date: date, sessionName: 'Rest', exercises: const []));
        }
      }
    } else {
      // Static fallback: fixed templates, used when no server exercise list.
      final templates = _templatesFor(focusAreas);
      var templateIndex = 0;
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
              for (final n in template.exercises) PlannedExercise(name: n, setsReps: setsReps),
            ],
          ));
        } else {
          days.add(DayPlan(date: date, sessionName: 'Rest', exercises: const []));
        }
      }
    }

    return WorkoutPlan(startDate: start, days: days);
  }

  /// Picks exercise names for one session, avoiding [used] exercises.
  /// Falls back to the full muscle-group pool if exclusion leaves too few.
  static List<String> _buildSessionNames(
    List<ServerExercise> pool,
    _DynSession sess,
    String fitnessLevel,
    Set<String> used,
    Random rng,
  ) {
    // Track within-session used so different pick groups don't overlap either.
    final sessionUsed = <String>{...used};
    final names = <String>[];
    for (final (kws, cnt) in sess.picks) {
      final picked = _pickExercises(pool, kws, fitnessLevel,
          count: cnt, exclude: sessionUsed, rng: rng);
      names.addAll(picked);
      sessionUsed.addAll(picked);
    }
    return names;
  }

  /// Returns the session-type rotation to use for the dynamic path.
  static List<_DynSession> _dynSessionsFor(Set<String> focusAreas) {
    final hasFullBody = focusAreas.isEmpty || focusAreas.contains('Full body');
    final includesPush = hasFullBody || focusAreas.any({'Chest', 'Shoulder', 'Arm'}.contains);
    final includesPull = hasFullBody || focusAreas.any({'Back', 'Arm'}.contains);
    final includesLower = hasFullBody || focusAreas.any({'Leg', 'Glutes'}.contains);

    final sessions = <_DynSession>[];
    if (hasFullBody) {
      sessions.add(_DynSession('Full Body Strength', [
        (_lowerKws, 1), (_pushKws, 1), (_pullKws, 1), (_coreKws, 1),
      ]));
    }
    if (includesPush) {
      sessions.add(_DynSession('Upper Body — Push', [(_pushKws, 3)]));
    }
    if (includesPull) {
      sessions.add(_DynSession('Upper Body — Pull', [(_pullKws, 3)]));
    }
    if (includesLower) {
      sessions.add(_DynSession('Lower Body & Core', [(_lowerKws, 2), (_coreKws, 1)]));
    }
    if (sessions.isEmpty) {
      sessions.add(_DynSession('Full Body Strength', [
        (_lowerKws, 1), (_pushKws, 1), (_pullKws, 1), (_coreKws, 1),
      ]));
    }
    return sessions;
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

  // Keywords to look for in an exercise name (lowercase) to infer equipment.
  static const _equipmentKeywords = <String, List<String>>{
    'Barbells': ['barbell'],
    'Dumbbells': ['dumbbell'],
    'Kettlebells': ['kettlebell'],
    'Resistance bands': ['band'],
    'Machines': ['machine', 'cable'],
  };

  static bool _matchesEquipment(ServerExercise ex, Set<String> equipment) {
    if (equipment.isEmpty || equipment.contains('Full gym')) return true;
    final lower = ex.name.toLowerCase();
    final needsSpecificEquipment =
        _equipmentKeywords.values.any((kws) => kws.any(lower.contains));
    if (!needsSpecificEquipment) return true;
    return equipment.any((equip) {
      final kws = _equipmentKeywords[equip];
      return kws != null && kws.any(lower.contains);
    });
  }

  // Exercise name keywords to exclude per health issue (case-insensitive).
  static const _healthExcludeKeywords = <String, List<String>>{
    'Back or hernia': ['deadlift', 'good morning', 'back extension', 'jefferson', 'hyperextension'],
    'Arms and shoulders': ['overhead press', 'push press', 'military press', 'lateral raise', 'front raise', 'skull', 'arnold press', 'behind the neck'],
    'Hip joints': ['hip thrust', 'glute bridge', 'lunge', 'hip abduction', 'hip adduction', 'curtsy'],
    'Knee': ['squat', 'lunge', 'leg press', 'leg extension', 'step up', 'box jump', 'jump squat'],
  };

  static bool _isExcludedByHealthIssues(ServerExercise ex, Set<String> healthIssues) {
    if (healthIssues.isEmpty) return false;
    final lower = ex.name.toLowerCase();
    return healthIssues.any((issue) {
      final kws = _healthExcludeKeywords[issue];
      return kws != null && kws.any(lower.contains);
    });
  }

  /// Returns a 'sets × reps' string tailored to the user's goals.
  static String _setsRepsFor(Set<String> goals, String fitnessLevel) {
    final sets = switch (fitnessLevel) {
      'Beginner' => 3,
      'Advanced' => 5,
      _ => 4,
    };
    final int reps;
    if (goals.any({'Burn fat', 'Weight loss', 'Increase endurance'}.contains)) {
      reps = 15;
    } else if (goals.contains('Build muscle')) {
      reps = 8;
    } else {
      reps = 10;
    }
    return '$sets × $reps';
  }

  /// Picks up to [count] exercises from [pool] whose muscle groups match
  /// [muscleKeywords], excluding any names in [exclude].
  ///
  /// Candidates are grouped into priority tiers (difficulty match + analysis
  /// support) and **shuffled within each tier** so each call returns a
  /// different random selection. If fewer than [count] remain after exclusion,
  /// the full muscle-group pool is used (allows reuse once all options are
  /// exhausted).
  static List<String> _pickExercises(
    List<ServerExercise> pool,
    List<String> muscleKeywords,
    String fitnessLevel, {
    int count = 3,
    Set<String>? exclude,
    Random? rng,
  }) {
    final random = rng ?? Random();

    bool hasMuscle(ServerExercise ex) =>
        ex.muscleGroups.any((g) => muscleKeywords.any(g.toLowerCase().contains));
    bool goodDifficulty(ServerExercise ex) =>
        ex.difficulty == null || fitnessLevel != 'Beginner' || ex.difficulty != 'Advanced';
    int tierOf(ServerExercise ex) =>
        (goodDifficulty(ex) ? 0 : 2) + (ex.supportsAnalysis ? 0 : 1);

    // Prefer non-excluded exercises; fall back to full pool if not enough.
    var candidates = pool
        .where(hasMuscle)
        .where((e) => exclude == null || !exclude.contains(e.name))
        .toList();
    if (candidates.length < count) {
      candidates = pool.where(hasMuscle).toList();
    }

    // Group by priority tier, shuffle within each tier, then flatten.
    final byTier = <int, List<ServerExercise>>{};
    for (final ex in candidates) {
      byTier.putIfAbsent(tierOf(ex), () => []).add(ex);
    }
    final ordered = <ServerExercise>[];
    for (final key in byTier.keys.toList()..sort()) {
      ordered.addAll(byTier[key]!..shuffle(random));
    }
    return ordered.take(count).map((e) => e.name).toList();
  }
}
