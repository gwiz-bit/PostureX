import '../models/user_session.dart';
import '../models/workout_plan.dart';
import '../services/api_client.dart';

/// Calls `POST /api/v1/coach/plan` and applies the result onto
/// [UserSession.plan] — the exact same "Personalize with AI" logic that used
/// to live only in `HomeScreen._generateAiPlan`. Pulled out so the AI Coach
/// chat screen can trigger the same action (see CHANGELOG 11/09/2026 —
/// before this, chat and the Home training plan were two disconnected
/// features that both happened to call Gemini) without duplicating it.
///
/// Callers handle their own loading state / error UI — this just does the
/// network call + state mutation and lets exceptions propagate.
Future<void> generateAndApplyAiPlan() async {
  final aiPlan = await ApiClient.instance.generateAiPlan();
  UserSession.plan.applyAiWeek([
    for (final day in aiPlan.days)
      (
        dayLabel: day.dayLabel,
        sessionName: day.sessionName,
        isRest: day.isRest,
        exercises: [
          for (final e in day.exercises) PlannedExercise(name: e.name, setsReps: e.setsReps),
        ],
        nutritionTip: day.nutritionTip,
      ),
  ]);
}
