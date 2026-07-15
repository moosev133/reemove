# ReeMove

ReeMove is a production-oriented Flutter/Firebase sports social network. The product combines social content, activity tracking, nearby discovery, sports communities, events, challenges, marketplace features, messaging, and an AI-ready service layer.

## Current implementation status

**Phase 1 - Project architecture and engineering foundation: complete.**

This repository currently contains:

- A feature-first Clean Architecture foundation.
- Riverpod dependency injection and application state.
- GoRouter navigation infrastructure.
- A premium adaptive light/dark design system.
- Environment/flavor configuration.
- Firebase bootstrap with optional App Check enforcement.
- Deny-by-default Firestore and Storage rules.
- Cloud Functions TypeScript foundation.
- Complete product roadmaps, screen catalog, model catalog, service catalog, widget catalog, and database schema.
- Unit-test foundations and CI workflow.

Later phases are intentionally tracked in `docs/PHASE_TRACKER.md`. Files completed in one phase should be modified only when a later feature genuinely requires a change.

## Architecture

ReeMove uses feature-first vertical slices. Every feature owns its presentation, application, domain, and data code. Cross-cutting code lives in `lib/core`; app composition lives in `lib/app`.

```text
presentation -> application -> domain <- data
                         repositories
```

The domain layer contains business entities and repository contracts. The data layer implements those contracts through Firebase or other providers. Riverpod wires dependencies together. Widgets never call Firebase directly.

## Requirements

- Flutter 3.44 or newer
- Dart 3.10 or newer
- Node.js 22
- Firebase CLI
- FlutterFire CLI
- A Firebase project for each environment: development, staging, production

## First-time setup

```bash
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID
cp .firebaserc.example .firebaserc
cd functions && npm install && cd ..
```

Run development mode:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=ENABLE_APP_CHECK=false
```

Run production mode:

```bash
flutter run --release \
  --dart-define=APP_FLAVOR=production \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY=YOUR_KEY
```

## Firebase safety

The initial rules are deliberately restrictive. Collections that have not yet been implemented are denied by the final catch-all rule. Each feature phase must add its rule changes and emulator tests in the same commit as the feature.

Deploy only after emulator tests pass:

```bash
firebase emulators:exec "flutter test" \
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## Documentation index

- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/SCREEN_CATALOG.md`
- `docs/FIREBASE_SCHEMA.md`
- `docs/MODEL_CATALOG.md`
- `docs/SERVICE_CATALOG.md`
- `docs/WIDGET_CATALOG.md`
- `docs/ARCHITECTURE_DECISIONS.md`
- `docs/PHASE_TRACKER.md`
- `docs/DEPLOYMENT_GUIDE.md`
