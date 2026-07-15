# ReeMove

ReeMove is a production-oriented Flutter and Firebase sports social network. The product combines social content, activity tracking, nearby discovery, sports communities, events, challenges, marketplace features, messaging, and an AI-ready service layer.

## Current implementation status

- **Phase 1 — Project architecture:** complete.
- **Phase 2 — Database design:** complete.
- **Phase 3 — Authentication:** complete.
- **Phase 4 — Onboarding:** complete.
- **Phase 5 — Main navigation:** complete.
- **Phase 6 — Social feed:** complete in this package.

The cumulative repository now contains:

- Feature-first Clean Architecture with Firebase-independent domain models.
- Riverpod dependency injection, async state, and guarded application routing.
- Premium responsive light/dark authentication, onboarding, six-tab application shell, social feed, reels, stories, and publishing UI.
- Email/password, Google, and Apple authentication plus provider linking.
- Transaction-backed server-owned usernames and account provisioning.
- Verification, recovery, recent-login controls, session revocation, and retryable deletion.
- A resumable ten-step onboarding flow for birthday, sports, levels, goals, avatar, location, discovery, accessibility, notifications, and review.
- Separate Home, Discover, Sports, Create, Messages, and Profile navigation stacks with state restoration.
- Guarded deep links that preserve the requested destination through authentication and onboarding.
- Android App Links, iOS Universal Links, and custom-scheme configuration automation.
- Ranked For You and Following feeds with cursor pagination, refresh, cache-aware reads, optimistic interactions, and reciprocal block filtering.
- Posts, carousels, reels, stories, comments, saves, reposts, reports, and unique view tracking.
- Crash-safe content drafts, owner-scoped uploads, trusted publishing, media jobs, and an authenticated video-processor callback.
- Trusted callable Functions for per-step persistence and atomic completion.
- Coarse public versus exact private location storage.
- Typed Firestore repositories, converters, indexes, Rules, Storage policies, seed data, and migration conventions.
- Firebase Auth, Firestore, Functions, and Storage emulator integration.
- Strict TypeScript Functions with App Check, rate limits, and audit events.
- CI, backend unit tests, Rules tests, Dart tests, and repository validation tooling.

Later phases are tracked in `docs/PHASE_TRACKER.md`. Existing files are changed only when integration requires it.

## Architecture

```text
presentation -> application -> domain <- data
                         repositories
```

Firebase and platform SDKs remain implementation details in the data layer. Riverpod composes dependencies. Widgets never call Firebase directly.

## Requirements

- Flutter 3.44 or newer
- Dart 3.10 or newer
- Node.js 22
- Java 21 for Firebase emulators
- Firebase CLI
- FlutterFire CLI
- Separate Firebase projects for development, staging, and production

## First-time setup

```bash
./scripts/bootstrap_project.sh
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID
cp .firebaserc.example .firebaserc
```

Then complete:

- `docs/AUTHENTICATION_SETUP.md`
- `docs/ONBOARDING_SETUP.md`
- `docs/DEEP_LINK_SETUP.md`
- `docs/MEDIA_PROCESSING_SETUP.md`

## Local emulators

Start all configured emulators and keep them running:

```bash
npm run emulators:start
```

In a second terminal, seed matching Auth and Firestore records:

```bash
npm run seed:running-emulators
```

Run Flutter against them in a third terminal:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Emulator-only users:

```text
Completed account
athlete@demo.reemove.app / ReeMoveDemo123!

Incomplete onboarding account
newcomer@demo.reemove.app / ReeMoveDemo123!
```

Never use these credentials outside the local `demo-reemove` emulator project.

## Verification

```bash
python3 scripts/validate_repository.py
npm run verify:backend
flutter analyze
flutter test --coverage
```

The backend command runs Functions linting, strict compilation, server policy tests, and Firestore/Storage Rules tests. Java and Firebase emulator binaries are required for the Rules suite.

## Production run

```bash
flutter run --release \
  --dart-define=APP_FLAVOR=production \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=ENABLE_ANALYTICS=true \
  --dart-define=FIREBASE_FUNCTIONS_REGION=europe-west1 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID \
  --dart-define=FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY=YOUR_KEY
```

## Documentation

- `docs/PHASE_6_COMPLETION.md`
- `docs/FEED_IMPLEMENTATION.md`
- `docs/MEDIA_PROCESSING_SETUP.md`
- `docs/PHASE_5_COMPLETION.md`
- `docs/NAVIGATION_IMPLEMENTATION.md`
- `docs/DEEP_LINK_SETUP.md`
- `docs/PHASE_4_COMPLETION.md`
- `docs/ONBOARDING_IMPLEMENTATION.md`
- `docs/ONBOARDING_SETUP.md`
- `docs/AUTHENTICATION_IMPLEMENTATION.md`
- `docs/FIREBASE_SCHEMA.md`
- `docs/DEPLOYMENT_GUIDE.md`
- `docs/VALIDATION_REPORT.md`
- `docs/PHASE_TRACKER.md`
