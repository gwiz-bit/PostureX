# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PostureX — "Your AI-Powered Fitness Coach". Three things live in this one repo:

1. **The Flutter app** (`lib/`, minus `lib/admin` and `lib/backend`) — the user-facing posture/fitness app.
2. **The FastAPI backend** (`lib/backend/`) — a full Python service (MySQL + JWT auth + MediaPipe pose analysis). Yes, it is nested under `lib/`, which is otherwise Dart-only; Flutter ignores non-Dart files there, so the layout works, but do not expect `lib/` to mean "Dart source" in this repo.
3. **The admin app** (`lib/admin/`) — a second Flutter app with its own `main()`, still running entirely on mock data.

`posturex_flutter/` is an **abandoned earlier prototype** (a complete second Flutter project, `description: "PostureX - AI posture correction app prototype"`). Nothing references it and it is not part of any build. Do not edit it, and do not treat its `lib/` as this app's source.

## Commands

### Flutter app

```bash
flutter pub get                      # install dependencies
flutter analyze                      # static analysis — must be clean before considering work done
flutter test                         # run the widget test suite (test/widget_test.dart)
flutter test --plain-name "Logging out"   # run a single test by (partial) name
flutter run -d chrome                # run with hot reload in a browser
flutter run -d windows               # run as a native Windows desktop app
flutter run -t lib/admin/admin_main.dart  # run the ADMIN app instead of the user app
flutter build web --release          # production web build (output: build/web)
```

There is no attached mobile simulator/device in this environment — development and visual verification have been done via `flutter build web --release`, serving `build/web` with `python -m http.server <port>`, and driving it with Playwright/Chromium for screenshots (Flutter web renders to a `<canvas>` via CanvasKit, so there is no real DOM text — Playwright must click by pixel coordinate, not by text selector, and screenshots are the only reliable way to verify layout).

### Backend (run from `lib/backend/`)

```bash
pip install -r requirements.txt
python download_models.py             # fetch the MediaPipe pose model (app/ml/models/*.task)
python create_tables.py               # create MySQL tables (also: sql/postureX123_schema.sql)
python create_admin.py                # seed an admin user
uvicorn app.main:app --reload --port 9000   # port 9000 is what the Flutter app expects
pytest                                # backend tests (tests/)
```

Config comes from `lib/backend/.env` (see `.env.example`): MySQL connection, `SECRET_KEY`, SMTP credentials for OTP email, and `GOOGLE_CLIENT_ID`. Interactive API docs at `/docs`.

## Architecture

### Client ⇄ backend split

The app talks to the backend over REST (`http`) and one WebSocket. **`ApiConfig` (`lib/config/api_config.dart`) hardcodes `http://localhost:9000`** — on a real Android emulator this must become `10.0.2.2:9000` (the emulator's alias for the host). `googleWebClientId` there must stay in sync with the backend's `GOOGLE_CLIENT_ID`, since the backend verifies the ID token's `aud` claim against it.

- `ApiClient` (`lib/services/api_client.dart`) — a thin singleton wrapper over the REST API (`ApiClient.instance`). Its `http.Client` is injectable so tests can pass a `MockClient`; `instance` is deliberately non-`final` for the same reason. Non-2xx responses throw `ApiException` carrying the backend's `detail` string.
- `TokenStorage` (`lib/services/token_storage.dart`) — persists the session in Android Keystore / iOS Keychain via `flutter_secure_storage`, never SharedPreferences. It delegates to a swappable `SecureStorageBackend` because the real plugin has no platform channel in the widget-test harness.
- `AnalyzeSocketService` (`lib/services/analyze_socket_service.dart`) — wraps `/api/v1/ws/analyze`: connect, send `{"exercise": ...}`, then stream base64 JPEG frames and receive per-frame `FrameAnalysisResult` (rep count, key angles, feedback). **This endpoint has no auth on the backend** — a known gap, not a bug to "fix" incidentally.

### Navigation

No router package (no go_router/auto_route) and no named routes — screens navigate with plain `Navigator.push`/`pushReplacement(MaterialPageRoute(...))`. The overall screen graph:

```
SplashScreen (auto-advances) → LoginScreen ⇄ RegisterScreen → OtpVerificationScreen
                                    │                                  │
                                    │                          OnboardingFlow (14 steps)
                                    │                                  │
                                    │                          PlanGeneratingScreen
                                    ▼                                  ▼
                                     MainShell (bottom-nav shell)
                        ── Home · Exercises · Workout · Progress · Profile ──
```

`MainShell` (`lib/screens/main_shell.dart`) hosts the 5 tabs in an `IndexedStack`, not a router — tab state is just an `int` in `State`. Reachable off the shell: `AnalyzeSessionScreen` (live camera + WebSocket), `UploadVideoScreen`, `SubscriptionScreen`.

### Auth flows

Registration is **OTP-gated**: `register()` creates an unverified account and emails a code; the account cannot log in until `verifyOtp()` succeeds, and that call is what returns the access token (so it doubles as the first login). Google Sign-In (`lib/services/google_auth_service.dart` → `POST /api/v1/auth/google`) auto-registers server-side on first use, so it is both login and register in one call.

**Admin backdoor:** `LoginScreen._submit` short-circuits on the hardcoded credentials `admin@gmail.com` / `123456` and pushes the mock-data admin `HomeScreen` *before* any API call. The admin area was intentionally left out of backend integration — it reads from `lib/admin/services/mock_data_service.dart`, not the server. Don't "clean up" that branch without a replacement.

### State: a static session, not a state management package

There is no provider/riverpod/bloc. `UserSession` (`lib/models/user_session.dart`) is a plain class of `static` fields acting as the entire app's in-memory session — screens read `UserSession.name`, `UserSession.plan`, etc. directly in `build()`. There are no listeners/streams, so updating `UserSession` does **not** reactively refresh already-built screens; a value only reflects on the next rebuild (typically after a navigation).

It now mixes two sources of truth: backend fields (`accessToken`, `userId`, `email`, set by `applyAuthSession`) and onboarding-only fields (`heightCm`, `weightKg`, `age`, `plan`, …) that have no backend equivalent and are set by `completeOnboarding`. `logOut()` resets **every** field back to its documented defaults — when adding a new session field, wire it into all the "set" paths (`completeOnboarding`, `applyAuthSession`) *and* `logOut`'s reset, and clear it from `TokenStorage` if it is persisted.

### Onboarding step system

`OnboardingFlow` (`lib/screens/onboarding/onboarding_flow.dart`) drives a linear questionnaire using generic, reusable step widgets in `lib/widgets/onboarding/` (`MultiSelectChipStep`, `SingleSelectListStep`, `SingleSelectCardStep`, `CheckboxListStep`, `NumberWheelStep`, `WorkoutFrequencyStep`, `WorkoutDaysStep`), each wrapped in the shared `OnboardingScaffold` chrome (back button, progress bar, pinned CTA). `OnboardingFlow` holds one mutable `OnboardingProfile` and an `int _index`, swapping `steps[_index]` on each `setState`.

**Gotcha:** every step instance in that list is given `key: ValueKey(step)`. This is required, not decorative — when two *consecutive* steps use the same step-widget class (e.g. three `NumberWheelStep`s in a row for height/age/weight), Flutter's element diffing reuses the `State` object across them unless the keys differ, silently carrying the previous step's `late`-initialized field values into the next step. This exact bug shipped once (age and weight both showed the height value) before the keys were added — never add a new step without a distinct key.

Only a subset of the answers has backend columns (`gender`, `height_cm`, `weight_kg`, `fitness_level`, and a `weekly_goal`); `ApiClient.updateProfile` sends exactly that subset. The rest stays client-side.

### Workout plan generation

`WorkoutPlan.generate(...)` (`lib/models/workout_plan.dart`) is a pure function that turns onboarding answers (selected weekdays, weekly frequency, focus areas, fitness level) into a 4-week, calendar-aligned plan (always starts on the most recent Sunday so the grid shows full weeks). Session content is templated (`Full Body`, `Upper Push`, `Upper Pull`, `Lower & Core`) and rotated across the user's chosen training days. Despite `PlanGeneratingScreen`'s framing and the backend's existence, **plan generation is still local and calls nothing** — the AI in this app is the pose analysis, not the planning.

### Backend layout (`lib/backend/app/`)

Standard FastAPI layering: `api/v1/routes/` (auth, users, workouts, videos, realtime, admin) → `crud/` → `models/` (SQLAlchemy, async MySQL via aiomysql) with `schemas/` for Pydantic I/O. `core/` holds settings, DB session, and JWT/password security.

The interesting part is `app/ml/`: `pose_estimator.py` runs the MediaPipe pose landmarker (`app/ml/models/pose_landmarker_full.task`, fetched by `download_models.py` — it is a binary, not in git as source), `angle_utils.py` computes joint angles, `rep_counter.py` does state-machine rep counting, and `analyzers/` holds per-exercise technique critique. **`ANALYZER_REGISTRY` in `routes/realtime.py` currently maps only `"squat"`** — any other exercise name silently falls back to `SquatAnalyzer`. Adding an exercise means adding an `ExerciseAnalyzer` subclass (see `analyzers/base.py`) and registering it there.

### Hand-drawn marks (no image/font assets)

`pubspec.yaml` declares no `assets:`. Brand marks are vector-drawn in code with `CustomPainter` instead of bundling images: `AppLogo` (`lib/widgets/app_logo.dart`, the PostureX "X" mark) and the Google "G" inside `lib/widgets/google_sign_in_button.dart`. Follow this same technique for any new icon/logo that needs to scale across sizes (18–48px have all been used) rather than adding image assets.

### Theming

`lib/theme/app_theme.dart` defines the single source of truth for colors (`AppColors`, dark background with a coral-orange `primary` accent) and `AppTheme.dark` (Material 3 `ThemeData`). Reuse `AppColors.*` rather than hardcoding hex values in widgets. The admin app has its own `lib/admin/admin_theme.dart`, but `admin_main.dart` still boots with `AppTheme.dark`.

### Testing patterns/gotchas (see `test/widget_test.dart`)

The suite is a handful of full-flow widget tests (register → onboarding → plan → home, login → logout, tapping a calendar day) rather than isolated per-widget unit tests. Anything touching the network must inject a `MockClient` into `ApiClient` and a fake `SecureStorageBackend` into `TokenStorage` — the real plugins have no platform channel under `flutter_test`. Recurring gotchas worth knowing before adding tests:

- **Lazy `ListView`:** `ListView(children: [...])` only mounts children within the viewport + cache extent — a widget below the fold won't be found by `find.text(...)` even though it's in the widget tree logically. Tests that need to reach content further down set a tall surface first: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Mid-transition "offstage" content:** asserting on text immediately after a `pushReplacement` (e.g. one frame into `PlanGeneratingScreen`/`SplashScreen`) can fail because the incoming route is technically offstage for a frame — use `find.text(..., skipOffstage: false)` in that specific situation.
- **Timed auto-navigation must use `AnimationController`, not `Future.delayed`:** `pumpAndSettle()` only waits out pending *frames/tickers*; a bare `Future.delayed` timer isn't tracked by it and the test will sail past the navigation before it fires. Both `PlanGeneratingScreen` and `SplashScreen` drive their auto-advance off an `AnimationController.addStatusListener` for exactly this reason — follow that pattern for any new timed transition.
- **Test-font fallback widens text:** the test environment doesn't load real fonts, so text measures wider than on a real device/browser, which has surfaced genuine `Row`/`spaceBetween` overflow bugs that don't show up in a manual device check. Prefer `Expanded`/`Flexible` + `overflow: TextOverflow.ellipsis` for any `Row` holding two text labels side by side.
