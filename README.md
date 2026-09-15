# PostureX

**Your AI-Powered Fitness Coach** — a Flutter app + FastAPI backend that watches
your form in real time through the camera, using on-device/server pose
estimation (MediaPipe) to count reps and correct technique as you train.

[![Backend CI](https://github.com/gwiz-bit/PostureX/actions/workflows/ci.yml/badge.svg)](https://github.com/gwiz-bit/PostureX/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## What it does

- **Real-time form analysis** — a live camera feed is streamed over WebSocket
  to a FastAPI backend running MediaPipe pose estimation; joint angles are
  computed frame-by-frame to count reps and flag technique errors (e.g.
  insufficient squat depth, knees caving in, rounded back) with spoken
  feedback (TTS).
- **25+ exercise-specific analyzers** covering ~280 of the ~410 exercises in
  the library (squat, deadlift, row, curl, presses, lunges, hip thrust,
  isolation moves, and more), each with tunable per-exercise thresholds an
  admin can adjust without a redeploy.
- **Video upload analysis** — record or upload a set instead of going live;
  the same analysis pipeline runs against the uploaded file and returns a
  rep count + accuracy summary.
- **AI Coach** — a Gemini-powered chat assistant that remembers conversation
  history server-side and can generate a personalized weekly workout plan
  informed by both your profile and what you've discussed with it.
- **Exercise library** — ~410 exercises across 16 muscle groups, each with a
  demo video, filterable by muscle group and equipment.
- **Progress tracking, subscriptions (MoMo payment), push notifications,**
  and a full **admin console** (11 screens) for managing exercises, users,
  posture-analysis thresholds, and revenue — all inside the same Flutter
  binary, gated by an `is_admin` role from the backend (no separate app, no
  hardcoded credentials).

## Tech stack

| Layer | Stack |
|---|---|
| Mobile app | Flutter/Dart, Clean Architecture (`domain` → `data` → `presentation`), no external state-management or DI framework |
| Backend | FastAPI (async), MySQL via `aiomysql`, JWT auth |
| Computer vision | MediaPipe Pose Landmarker, OpenCV |
| AI | Google Gemini (chat coach + plan generation) |
| Payments | MoMo gateway |
| Testing | `pytest` (435+ backend tests), `flutter test` (75+ widget/unit tests) |
| Tooling | `ruff` (lint/format), `flutter analyze`, GitHub Actions CI |

## Architecture highlights

- **Clean Architecture throughout**, including the entire admin surface —
  every feature is `domain/{entities,repositories,usecases}` →
  `data/{datasources,repositories}` → `presentation/{controllers,screens}`,
  wired by hand in a `<feature>_module.dart` composition root.
- **Pose estimation runs in a bounded worker pool**, not inline in the
  WebSocket handler — MediaPipe's `detect()` call is a blocking 30–60 ms CPU
  operation that would otherwise freeze the entire async event loop (and
  every other request) while a single user is mid-set.
- **Per-exercise posture rules are data, not code** — thresholds live in a
  database table and are read at analysis time, so tuning one exercise
  doesn't require a deploy or affect the 20+ other variants sharing the same
  analyzer class.
- **Real backend for the entire admin panel** — no mock data, no seeded demo
  mode; all 11 admin screens call real REST endpoints against the same
  database as the end-user app.

Full architectural notes, conventions, and the reasoning behind non-obvious
decisions live in [CLAUDE.md](CLAUDE.md) — including an extensive running
dev log of bugs found, root-caused, and fixed (rep-counting edge cases,
camera mirroring, latency, threshold tuning) with the evidence behind each
fix.

## Getting started

See [docs/SETUP.md](docs/SETUP.md) for full setup instructions (Windows,
with a one-command backend bootstrap script). Quick version:

```bash
# Backend
cd backend
./run.ps1                 # venv, deps, .env, ML model, DB, then starts the server

# App
flutter pub get
flutter run                # defaults to the deployed server; see docs/SETUP.md
                            # to point at a local backend instead
```

## Testing

```bash
# Backend
cd backend && pytest && ruff check .

# Flutter
flutter analyze && flutter test
```

Both suites run in CI on every push — see the badge above.

## Project status

This is an active student/team project, not a finished product. The dev log
in [CLAUDE.md](CLAUDE.md) is kept deliberately honest about what's verified
on real devices vs. only covered by automated tests — see its changelog for
current known gaps.

## License

[MIT](LICENSE)
