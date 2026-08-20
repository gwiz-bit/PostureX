# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PostureX — "Your AI-Powered Fitness Coach". Two things live in this one repo:

1. **The Flutter app** (`lib/`, minus `lib/backend`) — the user-facing posture/fitness app, ~70 Dart files across 24 screens, plus the 11-screen admin area in `lib/admin/`.
2. **The FastAPI backend** (`lib/backend/`) — a full Python service (MySQL + JWT auth + MediaPipe pose analysis). Yes, it is nested under `lib/`, which is otherwise Dart-only; Flutter ignores non-Dart files there, so the layout works, but do not expect `lib/` to mean "Dart source" in this repo.

**There is exactly one `main()`**, in `lib/main.dart` — `grep -rln "^void main()" lib/` proves it. `lib/admin/` is *not* a separate app: it is a set of screens inside the same binary, entered by logging in with an account the backend marks `is_admin`. Older notes describing an `admin_main.dart` entry point and a `-t` flag to launch it are wrong; that file does not exist.

## Commands

### Flutter app

```bash
flutter pub get                      # install dependencies
flutter analyze                      # static analysis — must be clean before considering work done
flutter test                         # run the widget test suite (test/widget_test.dart)
flutter test --plain-name "Logging out"   # run a single test by (partial) name
flutter run -d chrome                # run with hot reload in a browser
flutter run -d windows               # run as a native Windows desktop app
flutter build web --release          # production web build (output: build/web)
```

An **Android emulator is available** and has been verified end to end (`flutter emulators` to list, `flutter emulators --launch <id>`, then `flutter run -d emulator-5554`) — the app builds, installs as `com.example.posturex`, and reaches the backend. Two platform gotchas worth knowing before picking a target:

- **`flutter run -d windows` fails** with `Building with plugins requires symlink support` until Windows **Developer Mode** is on (`start ms-settings:developers`, then restart the editor). Plugin builds create symlinks under `windows/flutter/ephemeral/.plugin_symlinks`, which Windows forbids to non-admins otherwise. Nothing in the code can work around it.
- **Flutter web renders to a `<canvas>` via CanvasKit**, so there is no real DOM text. Verifying layout means `flutter build web --release`, serving `build/web` with `python -m http.server <port>`, and driving it with Playwright/Chromium clicking by *pixel coordinate* — never by text selector — with screenshots as the only reliable check.

Note that `flutter pub get` and Android builds rewrite the generated plugin registrants under `linux/`, `macos/`, and `windows/`. Those edits are build artifacts, not work — don't sweep them into an unrelated commit.

### Backend (run from `lib/backend/`)

```powershell
.\run.ps1                             # one-shot: venv, deps, .env, model, DB, then uvicorn — safe to re-run anytime
```

`run.ps1` handles first-time setup on a fresh clone (creates `.env` from `.env.example` and stops so you can fill in `DB_PASSWORD`, then on the next run creates the venv, installs deps, downloads the MediaPipe model, initializes the DB schema if empty) and is idempotent on repeat runs — on an already-populated DB it only fills in tables missing from `Base.metadata` (via `ensure_tables.py`, which unlike `create_tables.py` never drops `videos`/`workouts`). Use it after every `git pull` that adds a new model, instead of running the pieces below by hand:

```bash
pip install -r requirements.txt
python download_models.py             # fetch the MediaPipe pose model (app/ml/models/*.task)
python create_tables.py               # first-time init only — DROPS+recreates videos/workouts every run
python ensure_tables.py               # safe to re-run — only creates tables missing from Base.metadata
python create_admin.py                # seed an admin user
uvicorn app.main:app --reload --port 9000   # port 9000 is what the Flutter app expects
pytest                                # backend tests (tests/) — 84 currently, all passing
pytest --cov=app                      # coverage (58% at last measure)
ruff check .                          # lint — config in pyproject.toml; must be clean
ruff format .                         # formatter
```

`ruff`'s rule set is tuned in `pyproject.toml` so `ruff check .` is **green on the current tree** — a gate that opens red on 200 pre-existing issues just gets ignored. Several rules sit in `ignore` with a comment each explaining what it would cost to turn back on; ratchet them one at a time rather than widening `select`. One entry is load-bearing rather than stylistic: `flake8-bugbear.extend-immutable-calls` lists `fastapi.Depends`/`Query`/`File`/…, without which B008 fires ~105 false positives across every route.

Config comes from `lib/backend/.env` (see `.env.example`): MySQL connection, `SECRET_KEY`, SMTP credentials for OTP email, `GOOGLE_CLIENT_ID`, `GEMINI_API_KEY` (AI Coach), optional MoMo merchant keys (BE-14 — the defaults in `config.py` are MoMo's *public sandbox* keys, so payments work on a fresh clone), and optional FCM credentials (BE-13 — push is skipped silently when unset). `GOOGLE_CLIENT_ID` must stay byte-identical to `googleWebClientId` in `lib/config/api_config.dart`. Interactive API docs at `/docs`.

**`.env` encoding trap.** `slowapi` slurps `.env` on import purely because the file exists (`Config(".env")` in `slowapi/extension.py`), and `starlette.config.Config` opens it *without specifying an encoding* — so on a Vietnamese-locale Windows box the cp1252 codec hits the file's UTF-8 comments and the server dies at import with `UnicodeDecodeError: 'charmap' codec can't decode byte 0x81`, before uvicorn ever binds. `app/core/rate_limit.py` defuses this by passing `config_filename=os.devnull`; don't revert that to the default. The symptom only appears on some machines, so "works on mine" proves nothing here.

## Architecture

### Client ⇄ backend split

The app talks to the backend over REST (`http`) and one WebSocket. `ApiConfig` (`lib/config/api_config.dart`) picks the host from `Platform.isAndroid`: `10.0.2.2:9000` on Android, `localhost:9000` everywhere else. That switch is automatic — **don't hand-edit it for emulator testing**, which older notes used to call for. `10.0.2.2` is the emulator's alias for the *host loopback*, so a backend bound to `127.0.0.1` is reachable from the emulator; `--host 0.0.0.0` is only needed for a physical device over LAN (which also needs the machine's real IP, not `10.0.2.2` — see SETUP.md). `googleWebClientId` there must stay in sync with the backend's `GOOGLE_CLIENT_ID`, since the backend verifies the ID token's `aud` claim against it.

- `ApiClient` (`lib/services/api_client.dart`) — a thin singleton wrapper over the REST API (`ApiClient.instance`). Its `http.Client` is injectable so tests can pass a `MockClient`; `instance` is deliberately non-`final` for the same reason. Non-2xx responses throw `ApiException` carrying the backend's `detail` string.
- `TokenStorage` (`lib/services/token_storage.dart`) — persists the session in Android Keystore / iOS Keychain via `flutter_secure_storage`, never SharedPreferences. It delegates to a swappable `SecureStorageBackend` because the real plugin has no platform channel in the widget-test harness.
- `AnalyzeSocketService` (`lib/services/analyze_socket_service.dart`) — wraps `/api/v1/ws/analyze`: connect, send `{"exercise": ...}`, then stream base64 JPEG frames and receive per-frame `FrameAnalysisResult` (rep count, key angles, feedback). `AnalyzeSessionScreen` speaks that feedback aloud through `flutter_tts` and draws the landmarks with `SkeletonPainter`. **This endpoint has no auth on the backend** — a known gap, not a bug to "fix" incidentally.

Per-user statistics (streaks, weekly averages, accuracy trend) are computed **client-side** in `lib/utils/workout_stats.dart` from the raw `GET /workouts` list, and shared by the Progress and Profile screens. There is no `/stats` endpoint; the backend's only aggregation routes are `/admin/stats` and `/admin/revenue`, which are system-wide and admin-only.

### Navigation

No router package (no go_router/auto_route) and no named routes — screens navigate with plain `Navigator.push`/`pushReplacement(MaterialPageRoute(...))`. The overall screen graph:

```
SplashScreen (auto-advances) → LoginScreen ⇄ RegisterScreen → OtpVerificationScreen
                                 │    │                                │
                    ForgotPassword    │                        OnboardingFlow (14 steps)
                          ↓           │                                │
                   ResetPassword      │                        PlanGeneratingScreen
                                      ▼                                ▼
                        ┌─── is_admin ? ───┐
                        ▼                  ▼
             admin.HomeScreen        MainShell (bottom-nav shell)
             (11 admin screens)   ── Home · Exercises · Workout · Progress · Profile ──
```

`MainShell` (`lib/screens/main_shell.dart`) hosts the 5 tabs in an `IndexedStack`, not a router — tab state is just an `int` in `State`. Reachable off the shell: `AnalyzeSessionScreen` (live camera + WebSocket), `UploadVideoScreen`, `WorkoutSummaryScreen`, `ExerciseDetailScreen`, `AiCoachScreen` (Gemini chat), `NotificationsScreen` → `NotificationDetailScreen`, `EditProfileScreen`, and `SubscriptionScreen` → `PaymentWebViewScreen` (MoMo checkout in a `webview_flutter` view).

### Auth flows

Registration is **OTP-gated**: `register()` creates an unverified account and emails a code; the account cannot log in until `verifyOtp()` succeeds, and that call is what returns the access token (so it doubles as the first login). Google Sign-In (`lib/services/google_auth_service.dart` → `POST /api/v1/auth/google`) auto-registers server-side on first use, so it is both login and register in one call.

**Admin routing is server-driven.** After a successful login `LoginScreen` branches on `profile.isAdmin` — a field the backend fills from the `Roles` table — and pushes `admin.HomeScreen()` instead of `MainShell()`. There is no hardcoded-credential backdoor any more (an earlier `admin@gmail.com` / `123456` short-circuit was removed), and no mock data: `lib/admin/services/` does not exist, and all 11 admin screens go through `ApiClient`'s ~22 `/api/v1/admin/*` methods against the real server. To get into the admin area you need a real account whose role is `Admin` — `python create_admin.py` seeds one.

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

Standard FastAPI layering: `api/v1/routes/` (auth, users, workouts, videos, realtime, admin, notifications, subscriptions, exercises, coach) → `crud/` → `models/` (SQLAlchemy, async MySQL via aiomysql) with `schemas/` for Pydantic I/O. `core/` holds settings, DB session, rate limiting, and JWT/password security; `services/` holds the outbound integrations (email, Gemini, MoMo, FCM push, reminders).

The interesting part is `app/ml/`: `pose_estimator.py` runs the MediaPipe pose landmarker (`app/ml/models/pose_landmarker_full.task`, fetched by `download_models.py` — it is a binary, not in git as source), `angle_utils.py` computes joint angles, `rep_counter.py` does state-machine rep counting, and `analyzers/` holds per-exercise technique critique. `ANALYZER_REGISTRY` in `routes/realtime.py` maps **11 exercise-name keys onto 9 analyzer classes** (bench press and overhead press each answer to two spellings); anything not in the map silently falls back to `SquatAnalyzer` with a logged warning. Adding an exercise means adding an `ExerciseAnalyzer` subclass (see `analyzers/base.py`) and registering it there.

The analyzers are **hand-written angle thresholds, not a trained model** — `squat.py` hardcodes `KNEE_DEPTH_THRESHOLD = 95.0` and friends. Note that the DB *also* carries this knowledge: `ExercisePostureRules` and `PostureErrorTypes` are seeded with joint triples, min/max angles, and Vietnamese voice prompts, and **nothing reads them**. The two sources have already drifted (DB says back-straight ≥160°, `squat.py` uses 150°). Changing a threshold in the DB does nothing; edit the analyzer.

More broadly, `sql/postureX123_schema.sql` designs 25 tables but only 9 are wired to code. The 16 unused ones include `WorkoutSessions` / `SessionExercises` / `SessionReps` / `RealtimeFeedback` — i.e. the whole per-rep, per-error history the WebSocket currently computes and throws away, keeping only a summary the client posts back via `POST /workouts`. Uploaded videos are likewise stored but never analyzed (`analysis_summary`, `total_reps`, `accuracy_score` on `videos` are never written). Don't assume a table's existence means a feature works.

### Rate limiting and CORS

`app/core/rate_limit.py` owns the single shared `Limiter`. Two endpoints are limited: `/auth/forgot-password` (5/hour, anti email-spam) and `/auth/login` (10/minute;100/hour, anti brute-force). Two traps live here:

- The 429 body is `{"detail": ...}` in Vietnamese, produced by the module's own `rate_limit_handler`. slowapi's default handler emits `{"error": ...}`, and `ApiClient._decode` only reads `detail` — so reverting to the default makes the app show its generic "Something went wrong" instead of the real reason. A test in `tests/test_forgot_password.py` pins this shape.
- Do **not** set `headers_enabled=True` on the `Limiter`. On the success path slowapi calls `_inject_headers(kwargs.get("response"), …)` for any endpoint that doesn't return a `Response` — and these endpoints return Pydantic models — so it passes `None` and raises on *every successful request*. Enabling it would require adding `response: Response` to every rate-limited endpoint's signature; `rate_limit_handler` sets `Retry-After` itself instead.

CORS is **not** `["*"]`: that combined with `allow_credentials=True` makes Starlette echo back any caller's origin. `settings.ALLOWED_ORIGINS` takes explicit production origins from `.env`, and `ALLOWED_ORIGIN_REGEX` matches localhost on any port for `flutter run -d chrome` (which picks a random port). Native Android/iOS/Windows builds send no `Origin` header, so none of this affects them.

### Hand-drawn marks (no image/font assets)

The only bundled asset is `assets/video/` (currently `squat.mp4`, ~1.9 MB, played by `GuideVideoPlayer` as an exercise demo). **No image or font assets** — brand marks are vector-drawn in code with `CustomPainter`: `AppLogo` (`lib/widgets/app_logo.dart`, the PostureX "X" mark), the Google "G" inside `lib/widgets/google_sign_in_button.dart`, and the pose overlay in `lib/widgets/skeleton_painter.dart`. Follow this same technique for any new icon/logo that needs to scale across sizes (18–48px have all been used) rather than adding image assets.

### Theming

`lib/theme/app_theme.dart` defines the single source of truth for colors (`AppColors`, dark background with a coral-orange `primary` accent) and `AppTheme.dark` (Material 3 `ThemeData`). Reuse `AppColors.*` rather than hardcoding hex values in widgets. The admin screens carry their own palette in `lib/admin/admin_theme.dart`, but since they render inside the same `MaterialApp` that `lib/main.dart` builds, the ambient `ThemeData` is still `AppTheme.dark`.

### Testing patterns/gotchas (see `test/widget_test.dart`)

The suite is a handful of full-flow widget tests (register → onboarding → plan → home, login → logout, tapping a calendar day) rather than isolated per-widget unit tests. Anything touching the network must inject a `MockClient` into `ApiClient` and a fake `SecureStorageBackend` into `TokenStorage` — the real plugins have no platform channel under `flutter_test`. Recurring gotchas worth knowing before adding tests:

- **Lazy `ListView`:** `ListView(children: [...])` only mounts children within the viewport + cache extent — a widget below the fold won't be found by `find.text(...)` even though it's in the widget tree logically. Tests that need to reach content further down set a tall surface first: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Mid-transition "offstage" content:** asserting on text immediately after a `pushReplacement` (e.g. one frame into `PlanGeneratingScreen`/`SplashScreen`) can fail because the incoming route is technically offstage for a frame — use `find.text(..., skipOffstage: false)` in that specific situation.
- **Timed auto-navigation must use `AnimationController`, not `Future.delayed`:** `pumpAndSettle()` only waits out pending *frames/tickers*; a bare `Future.delayed` timer isn't tracked by it and the test will sail past the navigation before it fires. Both `PlanGeneratingScreen` and `SplashScreen` drive their auto-advance off an `AnimationController.addStatusListener` for exactly this reason — follow that pattern for any new timed transition.
- **Test-font fallback widens text:** the test environment doesn't load real fonts, so text measures wider than on a real device/browser, which has surfaced genuine `Row`/`spaceBetween` overflow bugs that don't show up in a manual device check. Prefer `Expanded`/`Flexible` + `overflow: TextOverflow.ellipsis` for any `Row` holding two text labels side by side.
