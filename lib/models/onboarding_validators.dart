/// Pure validation rules for onboarding steps — kept separate from the step
/// widgets so "is this step answered" isn't re-implemented (and re-typed
/// slightly differently) in every single-select step widget.
class OnboardingValidators {
  const OnboardingValidators._();

  /// A required single-select step (gender, motivation, fitness level,
  /// activity level) is answered once a value has been picked — there is
  /// no "empty but valid" state for these, unlike the optional multi-select
  /// and checkbox steps.
  static bool isSingleSelectValid(String? value) => value != null;
}
