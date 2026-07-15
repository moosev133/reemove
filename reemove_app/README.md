# ReeMove

ReeMove is a production-oriented Flutter and Firebase sports social network. The product combines social content, activity tracking, nearby discovery, sports communities, events, challenges, marketplace features, messaging, and an AI-ready service layer.

## Current implementation status

- **Phase 1 — Project architecture:** complete.
- **Phase 2 — Database design:** complete.
- **Phase 3 — Authentication:** complete in this package.

The cumulative repository now contains:

- Feature-first Clean Architecture with provider-neutral domain models.
- Riverpod dependency injection, async state, and authentication controllers.
- GoRouter session guards for signed-out, profile-required, email-verification, onboarding, blocked, and ready states.
- Premium responsive light/dark authentication UI.
- Email/password registration and sign-in.
- Google and Apple authentication adapters, plus provider linking.
- Transaction-backed server-owned username reservation and account provisioning.
- Email verification, password reset, provider-aware reauthentication, local sign-out, account-wide session revocation, and retryable account deletion.
- Typed Firestore repositories, converters, indexes, rules, Storage policies, deterministic seed data, and migration conventions.
- Firebase Auth, Firestore, Functions, and Storage emulator integration.
- Cloud Functions written in strict TypeScript with App Check enforcement, transactional rate limits, and privileged audit events.
- Opt-in, non-PII authentication analytics disabled by default and in emulator mode.
- CI, backend unit tests, Firebase Rules tests, and repository validation tooling.

Later phases are tracked in `docs/PHASE_TRACKER.md`. Existing files are changed only when integration requires it.

## Architecture

ReeMove uses feature-first vertical slices:

```text
presentation -> application -> domain <- data
                         repositories
```

The domain layer contains business entities and repository contracts. Firebase SDK types remain in the data layer. Riverpod wires dependencies together. Widgets never call Firebase directly.

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

Then enable Email/Password, Google, and Apple providers in Firebase Authentication and complete the platform-specific configuration in `docs/AUTHENTICATION_SETUP.md`.

## Local emulators

Start the emulators and seed a matching demo Auth user and Firestore dataset:

```bash
npm run seed:emulator
```

In another terminal, run Flutter against them:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Emulator-only credentials:

```text
Email: athlete@demo.reemove.app
Password: ReeMoveDemo123!
```

Never use these credentials outside the local `demo-reemove` emulator project.

## Backend verification

```bash
npm run verify:backend
```

This runs Functions linting, strict TypeScript compilation, server policy tests, and Firestore/Storage Rules tests. A Java runtime and the Firebase emulator binaries are required.

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

- `docs/PHASE_3_COMPLETION.md`
- `docs/AUTHENTICATION_IMPLEMENTATION.md`
- `docs/AUTHENTICATION_SETUP.md`
- `docs/FIREBASE_SCHEMA.md`
- `docs/DEPLOYMENT_GUIDE.md`
- `docs/VALIDATION_REPORT.md`
- `docs/PHASE_TRACKER.md`
