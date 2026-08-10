/// One exercise entry within an [AiPlanDay] (`POST /api/v1/coach/plan`).
class AiPlanExercise {
  const AiPlanExercise({required this.name, required this.setsReps});

  final String name;
  final String setsReps;

  factory AiPlanExercise.fromJson(Map<String, dynamic> json) => AiPlanExercise(
        name: json['name'] as String,
        setsReps: json['sets_reps'] as String,
      );
}

/// One day (Mon..Sun) of an AI-generated personalized plan.
class AiPlanDay {
  const AiPlanDay({
    required this.dayLabel,
    required this.sessionName,
    required this.isRest,
    required this.exercises,
    required this.nutritionTip,
  });

  final String dayLabel;
  final String sessionName;
  final bool isRest;
  final List<AiPlanExercise> exercises;
  final String nutritionTip;

  factory AiPlanDay.fromJson(Map<String, dynamic> json) => AiPlanDay(
        dayLabel: json['day_label'] as String,
        sessionName: json['session_name'] as String,
        isRest: json['is_rest'] as bool,
        exercises: (json['exercises'] as List)
            .map((e) => AiPlanExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
        nutritionTip: json['nutrition_tip'] as String,
      );
}

/// Full response from `POST /api/v1/coach/plan` — always exactly 7 entries,
/// Monday through Sunday.
class AiPlan {
  const AiPlan({required this.days});

  final List<AiPlanDay> days;

  factory AiPlan.fromJson(Map<String, dynamic> json) => AiPlan(
        days: (json['days'] as List)
            .map((e) => AiPlanDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
