# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PostureX — "Your AI-Powered Fitness Coach". Two things live in this one repo:

1. **The Flutter app** (`lib/`) — the user-facing posture/fitness app, ~220 Dart files across 34 screens, of which 11 are the admin area under `lib/features/admin_*/`. Most features (including all of admin) follow Clean Architecture: `domain/{entities,repositories,usecases}` → `data/{datasources,repositories}` → `presentation/{controllers,screens}`, plus a `<feature>_module.dart` composition root — no DI framework, modules wire dependencies by hand.
2. **The FastAPI backend** (`backend/`, a sibling of `lib/` at the repo root) — a full Python service (MySQL + JWT auth + MediaPipe pose analysis), talked to over REST/WebSocket only. It used to be nested at `lib/backend/`; it was moved to the repo root since `lib/` is otherwise Dart-only and the nesting had no upside.

**There is exactly one `main()`**, in `lib/main.dart` — `grep -rln "^void main()" lib/` proves it. The admin area is *not* a separate app: it is a set of screens inside the same binary, entered by logging in with an account the backend marks `is_admin`. Older notes describing an `admin_main.dart` entry point and a `-t` flag to launch it are wrong; that file does not exist.

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

An **Android emulator is available** and has been verified end to end (`flutter emulators` to list, `flutter emulators --launch <id>`, then `flutter run -d emulator-5554`) — the app builds, installs as `com.posturex.app`, and reaches the backend. Two platform gotchas worth knowing before picking a target:

- **`flutter run -d windows` fails** with `Building with plugins requires symlink support` until Windows **Developer Mode** is on (`start ms-settings:developers`, then restart the editor). Plugin builds create symlinks under `windows/flutter/ephemeral/.plugin_symlinks`, which Windows forbids to non-admins otherwise. Nothing in the code can work around it.
- **Flutter web renders to a `<canvas>` via CanvasKit**, so there is no real DOM text. Verifying layout means `flutter build web --release`, serving `build/web` with `python -m http.server <port>`, and driving it with Playwright/Chromium clicking by *pixel coordinate* — never by text selector — with screenshots as the only reliable check.

Note that `flutter pub get` and Android builds rewrite the generated plugin registrants under `linux/`, `macos/`, and `windows/`. Those edits are build artifacts, not work — don't sweep them into an unrelated commit.

### Backend (run from `backend/`)

```powershell
.\run.ps1                             # one-shot: venv, deps, .env, model, DB, then uvicorn — safe to re-run anytime
```

`run.ps1` handles first-time setup on a fresh clone (creates `.env` from `.env.example` and stops so you can fill in `DB_PASSWORD`, then on the next run creates the venv, installs deps, downloads the MediaPipe model, initializes the DB schema if empty) and is idempotent on repeat runs — on an already-populated DB it only fills in tables missing from `Base.metadata` (via `scripts/ensure_tables.py`, which unlike `scripts/create_tables.py` never drops `videos`/`workouts`). Use it after every `git pull` that adds a new model, instead of running the pieces below by hand. All one-off maintenance scripts (DB setup, admin seeding, model download, data export/import, manual job triggers) live in `backend/scripts/` — nothing script-like sits loose at the `backend/` top level:

```bash
pip install -r requirements.txt
python scripts/download_models.py     # fetch the MediaPipe pose model (app/ml/models/*.task)
python scripts/create_tables.py       # first-time init only — DROPS+recreates videos/workouts every run
python scripts/ensure_tables.py       # safe to re-run — only creates tables missing from Base.metadata
python scripts/create_admin.py        # seed an admin user
uvicorn app.main:app --reload --port 9000   # port 9000 is what the Flutter app expects
pytest                                # backend tests (tests/) — 123 currently, all passing
pytest --cov=app                      # coverage (58% when last measured, before the library import)
ruff check .                          # lint — config in pyproject.toml; must be clean
ruff format .                         # formatter
```

`ruff`'s rule set is tuned in `pyproject.toml` so `ruff check .` is **green on the current tree** — a gate that opens red on 200 pre-existing issues just gets ignored. Several rules sit in `ignore` with a comment each explaining what it would cost to turn back on; ratchet them one at a time rather than widening `select`. One entry is load-bearing rather than stylistic: `flake8-bugbear.extend-immutable-calls` lists `fastapi.Depends`/`Query`/`File`/…, without which B008 fires ~105 false positives across every route.

Config comes from `backend/.env` (see `.env.example`): MySQL connection, `SECRET_KEY`, SMTP credentials for OTP email, `GOOGLE_CLIENT_ID`, `GEMINI_API_KEY` (AI Coach), optional MoMo merchant keys (BE-14 — the defaults in `config.py` are MoMo's *public sandbox* keys, so payments work on a fresh clone), and optional FCM credentials (BE-13 — push is skipped silently when unset). `GOOGLE_CLIENT_ID` must stay byte-identical to `googleWebClientId` in `lib/config/api_config.dart`. Interactive API docs at `/docs` — but only when `DEBUG=True`; on a real deployment `docs_url`/`redoc_url`/`openapi_url` are all `None` so the full API surface isn't public.

**`.env` encoding trap.** `slowapi` slurps `.env` on import purely because the file exists (`Config(".env")` in `slowapi/extension.py`), and `starlette.config.Config` opens it *without specifying an encoding* — so on a Vietnamese-locale Windows box the cp1252 codec hits the file's UTF-8 comments and the server dies at import with `UnicodeDecodeError: 'charmap' codec can't decode byte 0x81`, before uvicorn ever binds. `app/core/rate_limit.py` defuses this by passing `config_filename=os.devnull`; don't revert that to the default. The symptom only appears on some machines, so "works on mine" proves nothing here.

## Architecture

### Client ⇄ backend split

The app talks to the backend over REST (`http`) and one WebSocket. `ApiConfig` (`lib/config/api_config.dart`) **defaults to the deployed VPS**; a build-time `--dart-define=API_BASE_URL=…` override wins when set, and `wsUrl` derives `ws`/`wss` from whichever URL is in play. Running against a backend on your own machine is the case that now needs the flag:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:9000    # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:9000   # Windows/web
```

`10.0.2.2` is the emulator's alias for the *host loopback*, so a backend bound to `127.0.0.1` is reachable from the emulator; `--host 0.0.0.0` is only needed for a physical device over LAN (which also needs the machine's real IP — see docs/SETUP.md).

The default points at the server on purpose, and the direction matters. `API_BASE_URL` is a **compile-time** constant, not runtime config — every build has to pass it again, and it is not stored anywhere. With a dev address as the fallback, forgetting the flag produced an app that silently pointed at `10.0.2.2` and reported "Could not reach the server" while the server was fine; worse, a release build made the same way would have shipped pointing at an address that only resolves on an emulator. Failing towards the real server means whoever forgets is a developer running a local backend, who finds out immediately. `.vscode/launch.json` carries ready-made configurations for both directions, and `test/config/api_config_test.dart` fails if the default drifts back to a dev host.

⚠️ The default is currently a **bare IP over HTTP**. Before any real release it has to become an HTTPS domain: iOS App Transport Security blocks `http://` outright, many school/office networks block non-standard ports like 9000, and an IP baked into a shipped build means every installed app breaks the day the server moves. `googleWebClientId` there must stay in sync with the backend's `GOOGLE_CLIENT_ID`, since the backend verifies the ID token's `aud` claim against it.

- `ApiClient` (`lib/services/api_client.dart`) — a thin singleton wrapper over the REST API (`ApiClient.instance`). Its `http.Client` is injectable so tests can pass a `MockClient`; `instance` is deliberately non-`final` for the same reason. Non-2xx responses throw `ApiException` carrying the backend's `detail` string. Every call carries a timeout, because `package:http` has none by default and a stalled request would otherwise hang the screen forever: 20s for ordinary calls, **90s for `/coach/*`** (Gemini legitimately takes 5-20s), **5 minutes for video uploads**. A timeout surfaces as `ApiException(408, …)` so existing `catch` blocks keep working.
- `TokenStorage` (`lib/services/token_storage.dart`) — persists the session in Android Keystore / iOS Keychain via `flutter_secure_storage`, never SharedPreferences. It delegates to a swappable `SecureStorageBackend` because the real plugin has no platform channel in the widget-test harness.
- `AnalyzeSocketService` (`lib/services/analyze_socket_service.dart`) — wraps `/api/v1/ws/analyze`: connect, send `{"exercise": ...}`, then stream base64 JPEG frames and receive per-frame `FrameAnalysisResult` (rep count, key angles, feedback). `AnalyzeSessionScreen` speaks that feedback aloud through `flutter_tts` and draws the landmarks with `SkeletonPainter`. The endpoint **does** require auth: the token goes in the query string (`/ws/analyze?token=…`) rather than a header, because many WebSocket clients can't set headers during the handshake. Older notes calling this an unauthenticated gap are out of date.

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

**Admin routing is server-driven.** After a successful login `LoginScreen` branches on `profile.isAdmin` — a field the backend fills from the `Roles` table — and pushes `admin.HomeScreen()` instead of `MainShell()`. There is no hardcoded-credential backdoor any more (an earlier `admin@gmail.com` / `123456` short-circuit was removed), and no mock data: all 11 admin screens (`lib/features/admin_*/`) go through `ApiClient`'s ~22 `/api/v1/admin/*` methods, wrapped behind each admin feature's own repository/use-case layer, against the real server. To get into the admin area you need a real account whose role is `Admin` — `python scripts/create_admin.py` seeds one.

### State: a static session, not a state management package

There is no provider/riverpod/bloc. `UserSession` (`lib/models/user_session.dart`) is a plain class of `static` fields acting as the entire app's in-memory session — screens read `UserSession.name`, `UserSession.plan`, etc. directly in `build()`. There are no listeners/streams, so updating `UserSession` does **not** reactively refresh already-built screens; a value only reflects on the next rebuild (typically after a navigation).

It now mixes two sources of truth: backend fields (`accessToken`, `userId`, `email`, set by `applyAuthSession`) and onboarding-only fields (`heightCm`, `weightKg`, `age`, `plan`, …) that have no backend equivalent and are set by `completeOnboarding`. `logOut()` resets **every** field back to its documented defaults — when adding a new session field, wire it into all the "set" paths (`completeOnboarding`, `applyAuthSession`) *and* `logOut`'s reset, and clear it from `TokenStorage` if it is persisted.

### Onboarding step system

`OnboardingFlow` (`lib/screens/onboarding/onboarding_flow.dart`) drives a linear questionnaire using generic, reusable step widgets in `lib/widgets/onboarding/` (`MultiSelectChipStep`, `SingleSelectListStep`, `SingleSelectCardStep`, `CheckboxListStep`, `NumberWheelStep`, `WorkoutFrequencyStep`, `WorkoutDaysStep`), each wrapped in the shared `OnboardingScaffold` chrome (back button, progress bar, pinned CTA). `OnboardingFlow` holds one mutable `OnboardingProfile` and an `int _index`, swapping `steps[_index]` on each `setState`.

**Gotcha:** every step instance in that list is given `key: ValueKey(step)`. This is required, not decorative — when two *consecutive* steps use the same step-widget class (e.g. three `NumberWheelStep`s in a row for height/age/weight), Flutter's element diffing reuses the `State` object across them unless the keys differ, silently carrying the previous step's `late`-initialized field values into the next step. This exact bug shipped once (age and weight both showed the height value) before the keys were added — never add a new step without a distinct key.

Only a subset of the answers has backend columns (`gender`, `height_cm`, `weight_kg`, `fitness_level`, and a `weekly_goal`); `ApiClient.updateProfile` sends exactly that subset. The rest stays client-side.

### Workout plan generation

`WorkoutPlan.generate(...)` (`lib/models/workout_plan.dart`) is a pure function that turns onboarding answers (selected weekdays, weekly frequency, focus areas, fitness level) into a 4-week, calendar-aligned plan (always starts on the most recent Sunday so the grid shows full weeks). Session content is templated (`Full Body`, `Upper Push`, `Upper Pull`, `Lower & Core`) and rotated across the user's chosen training days. Despite `PlanGeneratingScreen`'s framing and the backend's existence, **plan generation is still local and calls nothing** — the AI in this app is the pose analysis, not the planning.

### Backend layout (`backend/app/`)

Standard FastAPI layering: `api/v1/routes/` (auth, users, workouts, videos, realtime, admin, notifications, subscriptions, exercises, coach) → `crud/` → `models/` (SQLAlchemy, async MySQL via aiomysql) with `schemas/` for Pydantic I/O. `core/` holds settings, DB session, rate limiting, and JWT/password security; `services/` holds the outbound integrations (email, Gemini, MoMo, FCM push, reminders).

The interesting part is `app/ml/`: `pose_estimator.py` runs the MediaPipe pose landmarker (`app/ml/models/pose_landmarker_full.task`, fetched by `scripts/download_models.py` — it is a binary, gitignored, not committed as source), `angle_utils.py` computes joint angles, `rep_counter.py` does state-machine rep counting, and `analyzers/` holds per-exercise technique critique.

**Never call `PoseEstimator.estimate()` straight from async code.** MediaPipe `detect()` is a 30-60 ms CPU call that doesn't yield, so running it inside the WebSocket handler froze the *entire* event loop — logins and every other request queued behind whoever was mid-workout. `app/ml/pose_estimator_pool.py` moves it onto worker threads and caps how many run at once. A pool rather than a bare `asyncio.to_thread` because `PoseLandmarker` is **not thread-safe**: two threads sharing one instance is undefined behaviour. Instances are built lazily, sized by CPU count and capped at 4.

`ANALYZER_REGISTRY` lives in `app/ml/analyzers/registry.py` (not `routes/realtime.py` — `routes/exercises.py` needs it too, and importing the realtime module would drag mediapipe in just to read some names). It maps **112 exercise-name keys onto 9 analyzer classes**, covering 106 of the ~417 library exercises. The names are listed one by one on purpose: substring matching looks tempting but is wrong in a way that misleads users — "Barbell Upright Row" is a shoulder exercise, "Nar-row Pulldown" merely contains the letters, "Rowing Machine Steady State" is cardio. Variants are also excluded when the analyzer averages or compares both sides (a one-armed row never reaches the contraction threshold because the idle arm drags the average), and split squats map to `LungeAnalyzer` rather than `SquatAnalyzer` because lunge takes `min()` of the two knees where squat averages them. `tests/test_analyzer_registry.py` pins those exclusions. Anything not in the map falls back to `SquatAnalyzer` with a logged warning, but clients should use the `supports_analysis` flag on `GET /exercises` so users never reach that fallback.

The analyzers are **hand-written angle thresholds, not a trained model** — `squat.py` hardcodes `KNEE_DEPTH_THRESHOLD = 95.0` and friends. Note that the DB *also* carries this knowledge: `ExercisePostureRules` and `PostureErrorTypes` are seeded with joint triples, min/max angles, and Vietnamese voice prompts, and **nothing reads them**. The two sources have already drifted (DB says back-straight ≥160°, `squat.py` uses 150°). Changing a threshold in the DB does nothing; edit the analyzer.

More broadly, `sql/postureX123_schema.sql` designs 25 tables (the live DB has 35 once views and later additions are counted) and most are still not wired to code. `MuscleGroups`/`ExerciseMuscleGroups` *are* wired now — `app/models/muscle_group.py` backs the 16-muscle-group filter on the Exercises tab. The unused ones include `WorkoutSessions` / `SessionExercises` / `SessionReps` / `RealtimeFeedback` — i.e. the whole per-rep, per-error history the WebSocket currently computes and throws away, keeping only a summary the client posts back via `POST /workouts`. Uploaded videos are likewise stored but never analyzed (`analysis_summary`, `total_reps`, `accuracy_score` on `videos` are never written). Don't assume a table's existence means a feature works.

### Rate limiting and CORS

`app/core/rate_limit.py` owns the single shared `Limiter`. Four endpoints are limited: `/auth/forgot-password` (5/hour, anti email-spam), `/auth/login` (10/minute;100/hour, anti brute-force), and both AI Coach routes — `/coach/chat` (10/minute;100/hour) and `/coach/plan` (5/minute;20/hour) — because each call spends real Gemini quota, so an unlimited endpoint is an unlimited bill. Two traps live here:

- The 429 body is `{"detail": ...}` in Vietnamese, produced by the module's own `rate_limit_handler`. slowapi's default handler emits `{"error": ...}`, and `ApiClient._decode` only reads `detail` — so reverting to the default makes the app show its generic "Something went wrong" instead of the real reason. A test in `tests/test_forgot_password.py` pins this shape.
- Do **not** set `headers_enabled=True` on the `Limiter`. On the success path slowapi calls `_inject_headers(kwargs.get("response"), …)` for any endpoint that doesn't return a `Response` — and these endpoints return Pydantic models — so it passes `None` and raises on *every successful request*. Enabling it would require adding `response: Response` to every rate-limited endpoint's signature; `rate_limit_handler` sets `Retry-After` itself instead.

CORS is **not** `["*"]`: that combined with `allow_credentials=True` makes Starlette echo back any caller's origin. `settings.ALLOWED_ORIGINS` takes explicit production origins from `.env`, and `ALLOWED_ORIGIN_REGEX` matches localhost on any port for `flutter run -d chrome` (which picks a random port). Native Android/iOS/Windows builds send no `Origin` header, so none of this affects them.

### Exercise library and demo videos

The library is ~417 exercises across 16 muscle groups, imported from a folder tree of 412 `.mp4` files by `scripts/import_exercise_videos.py` (`--dry-run` first; `--copy` leaves the source intact so a failed run can be retried). Exercise names are derived from filenames, so `band-assisted-pull-up.mp4` becomes "Band Assisted Pull Up".

**The app finds videos through the DB column, not by scanning a folder.** `Exercises.DemoVideoUrl` holds a *relative* path (`/media/exercise-videos/<file>.mp4`) that the client prefixes with `ApiConfig.baseUrl`. Copying files onto the server without updating that column does nothing at all — a mistake that has already cost a debugging session.

Serving them requires a login: `main.py` handles `/media/exercise-videos/{filename}` with a `get_current_user` dependency instead of mounting `StaticFiles`, because much of the library is licensed third-party footage that shouldn't sit on a public URL. Two consequences worth remembering — `{filename}` matches a single path segment, so files must stay **flat** in `storage/exercise_videos/` (no per-muscle-group subfolders); and `video_player` bypasses `ApiClient` entirely, so `GuideVideoPlayer` has to attach the bearer token itself via `httpHeaders`.

### Deployment

The backend runs on a Cloudfly VPS (Ubuntu, 2 vCPU / 4 GB) under systemd as `posturex.service`, with MySQL local to that box and port 3306 closed to the internet. There is no nginx and no TLS yet, so it answers plain HTTP on port 9000 — which is why iOS can't talk to it and why restrictive networks sometimes can't either.

Real credentials (SSH key path, DB password, deploy commands) live in `DEPLOY_SERVER.md`, which is **gitignored and only exists on team machines** — ask a teammate rather than looking for it in the repo. `.gitignore` blocks that file at both the repo root and under `docs/`, plus `*.pem`/`*.key`, after private keys were found sitting untracked in the working tree where a single `git add .` would have published them.

Deploying is `git pull` + `systemctl restart posturex` on the server. Note that `backend/.env` is **not** in git and does not travel with a pull: any new setting has to be added on the server by hand, which is exactly how a stale `GEMINI_MODEL` once survived several deploys.

### Hand-drawn marks (no image/font assets)

The only bundled asset is `assets/video/` (currently `squat.mp4`, ~1.9 MB, played by `GuideVideoPlayer` as an exercise demo). **No image or font assets** — brand marks are vector-drawn in code with `CustomPainter`: `AppLogo` (`lib/widgets/app_logo.dart`, the PostureX "X" mark), the Google "G" inside `lib/widgets/google_sign_in_button.dart`, and the pose overlay in `lib/widgets/skeleton_painter.dart`. Follow this same technique for any new icon/logo that needs to scale across sizes (18–48px have all been used) rather than adding image assets.

### Theming

`lib/theme/app_theme.dart` defines the single source of truth for colors (`AppColors`, dark background with a coral-orange `primary` accent) and `AppTheme.dark` (Material 3 `ThemeData`). Reuse `AppColors.*` rather than hardcoding hex values in widgets. The admin screens carry their own palette in `lib/theme/admin_theme.dart` (plus shared widgets in `lib/widgets/admin/`), but since they render inside the same `MaterialApp` that `lib/main.dart` builds, the ambient `ThemeData` is still `AppTheme.dark`.

### Testing patterns/gotchas (see `test/widget_test.dart`)

The suite is 17 tests: mostly full-flow widget tests (register → onboarding → plan → home, login → logout, tapping a calendar day) plus a few pure unit tests under `test/features/`, `test/config/` and `test/services/`. Anything touching the network must inject a `MockClient` into `ApiClient` and a fake `SecureStorageBackend` into `TokenStorage` — the real plugins have no platform channel under `flutter_test`. Recurring gotchas worth knowing before adding tests:

- **Lazy `ListView`:** `ListView(children: [...])` only mounts children within the viewport + cache extent — a widget below the fold won't be found by `find.text(...)` even though it's in the widget tree logically. Tests that need to reach content further down set a tall surface first: `tester.view.physicalSize = const Size(500, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
- **Mid-transition "offstage" content:** asserting on text immediately after a `pushReplacement` (e.g. one frame into `PlanGeneratingScreen`/`SplashScreen`) can fail because the incoming route is technically offstage for a frame — use `find.text(..., skipOffstage: false)` in that specific situation.
- **Timed auto-navigation must use `AnimationController`, not `Future.delayed`:** `pumpAndSettle()` only waits out pending *frames/tickers*; a bare `Future.delayed` timer isn't tracked by it and the test will sail past the navigation before it fires. Both `PlanGeneratingScreen` and `SplashScreen` drive their auto-advance off an `AnimationController.addStatusListener` for exactly this reason — follow that pattern for any new timed transition.
- **Test-font fallback widens text:** the test environment doesn't load real fonts, so text measures wider than on a real device/browser, which has surfaced genuine `Row`/`spaceBetween` overflow bugs that don't show up in a manual device check. Prefer `Expanded`/`Flexible` + `overflow: TextOverflow.ellipsis` for any `Row` holding two text labels side by side.
