# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PostureX — a Flutter app (posture/fitness tracking, "Your AI-Powered Fitness Coach"). No backend: all data is generated/held client-side for the current session, no persistence across restarts.

## Commands

```bash
flutter pub get                      # install dependencies
flutter analyze                      # static analysis — must be clean before considering work done
flutter test                         # run the full widget test suite (test/widget_test.dart)
flutter test --plain-name "Logging out"   # run a single test by (partial) name
flutter build web --release          # production web build (output: build/web)
flutter run -d chrome                # run with hot reload in a browser
flutter run -d windows               # run as a native Windows desktop app
```

There is no attached mobile simulator/device in this environment — development and visual verification have been done via `flutter build web --release`, serving `build/web` with `python -m http.server <port>`, and driving it with Playwright/Chromium for screenshots (Flutter web renders to a `<canvas>` via CanvasKit, so there is no real DOM text — Playwright must click by pixel coordinate, not by text selector, and screenshots are the only reliable way to verify layout).

## Architecture

### Navigation

No router package (no go_router/auto_route) and no named routes — screens navigate with plain `Navigator.push`/`pushReplacement(MaterialPageRoute(...))`. The overall screen graph:

```
SplashScreen (auto-advances) → LoginScreen ⇄ RegisterScreen
                                    │                │
                                    │        OnboardingFlow (14 steps)
                                    │                │
                                    │        PlanGeneratingScreen
                                    ▼                ▼
                                     MainShell (bottom-nav shell)
                        ── Home · Exercises · Workout · Progress · Profile ──
```

`MainShell` (`lib/screens/main_shell.dart`) hosts the 5 tabs in an `IndexedStack`, not a router — tab state is just an `int` in `State`.

### State: a static session, not a state management package

There is no provider/riverpod/bloc. `UserSession` (`lib/models/user_session.dart`) is a plain class of `static` fields acting as the entire app's in-memory session — screens read `UserSession.name`, `UserSession.plan`, etc. directly in `build()`. There are no listeners/streams, so updating `UserSession` does **not** reactively refresh already-built screens; a value only reflects on the next rebuild (typically after a navigation). `UserSession.logOut()` resets every field back to its documented defaults — when adding a new session field, wire it into both the "set" paths (`completeOnboarding`, `signInWithGoogle`) and `logOut`'s reset.

### Onboarding step system

`OnboardingFlow` (`lib/screens/onboarding/onboarding_flow.dart`) drives a linear questionnaire using generic, reusable step widgets in `lib/widgets/onboarding/` (`MultiSelectChipStep`, `SingleSelectListStep`, `SingleSelectCardStep`, `CheckboxListStep`, `NumberWheelStep`, `WorkoutFrequencyStep`, `WorkoutDaysStep`), each wrapped in the shared `OnboardingScaffold` chrome (back button, progress bar, pinned CTA). `OnboardingFlow` holds one mutable `OnboardingProfile` and an `int _index`, swapping `steps[_index]` on each `setState`.

**Gotcha:** every step instance in that list is given `key: ValueKey(step)`. This is required, not decorative — when two *consecutive* steps use the same step-widget class (e.g. three `NumberWheelStep`s in a row for height/age/weight), Flutter's element diffing reuses the `State` object across them unless the keys differ, silently carrying the previous step's `late`-initialized field values into the next step. This exact bug shipped once (age and weight both showed the height value) before the keys were added — never add a new step without a distinct key.

### Workout plan generation

`WorkoutPlan.generate(...)` (`lib/models/workout_plan.dart`) is a pure function that turns onboarding answers (selected weekdays, weekly frequency, focus areas, fitness level) into a 4-week, calendar-aligned plan (always starts on the most recent Sunday so the grid shows full weeks). Session content is templated (`Full Body`, `Upper Push`, `Upper Pull`, `Lower & Core`) and rotated across the user's chosen training days — it does not call any AI/network service despite `PlanGeneratingScreen`'s framing.

### Hand-drawn marks (no image/font assets)

`pubspec.yaml` declares no `assets:`. Brand marks are vector-drawn in code with `CustomPainter` instead of bundling images: `AppLogo` (`lib/widgets/app_logo.dart`, the PostureX "X" mark) and the Google "G" inside `lib/widgets/google_sign_in_button.dart`. Follow this same technique for any new icon/logo that needs to scale across sizes (18–48px have all been used) rather than adding image assets.

### Theming

`lib/theme/app_theme.dart` defines the single source of truth for colors (`AppColors`, dark background with a coral-orange `primary` accent) and `AppTheme.dark` (Material 3 `ThemeData`). Reuse `AppColors.*` rather than hardcoding hex values in widgets.

### Testing patterns/gotchas (see `test/widget_test.dart`)

The suite is a handful of full-flow widget tests (register → onboarding → plan → home, login → logout, tapping a calendar day) rather than isolated per-widget unit tests. Recurring gotchas worth knowing before adding tests:

- **Lazy `ListView`:** `ListView(children: [...])` only mounts children within the viewport + cache extent — a widget below the fold won't be found by `find.text(...)` even though it's in the widget tree logically. Tests that need to reach content further down set a tall surface first: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Mid-transition "offstage" content:** asserting on text immediately after a `pushReplacement` (e.g. one frame into `PlanGeneratingScreen`/`SplashScreen`) can fail because the incoming route is technically offstage for a frame — use `find.text(..., skipOffstage: false)` in that specific situation.
- **Timed auto-navigation must use `AnimationController`, not `Future.delayed`:** `pumpAndSettle()` only waits out pending *frames/tickers*; a bare `Future.delayed` timer isn't tracked by it and the test will sail past the navigation before it fires. Both `PlanGeneratingScreen` and `SplashScreen` drive their auto-advance off an `AnimationController.addStatusListener` for exactly this reason — follow that pattern for any new timed transition.
- **Test-font fallback widens text:** the test environment doesn't load real fonts, so text measures wider than on a real device/browser, which has surfaced genuine `Row`/`spaceBetween` overflow bugs that don't show up in a manual device check. Prefer `Expanded`/`Flexible` + `overflow: TextOverflow.ellipsis` for any `Row` holding two text labels side by side.
