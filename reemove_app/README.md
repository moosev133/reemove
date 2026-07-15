# ReeMove

ReeMove is a production-oriented Flutter/Firebase sports social network. The product combines social content, activity tracking, nearby discovery, sports communities, events, challenges, marketplace features, messaging, and an AI-ready service layer.

## Current implementation status

- **Phase 1 — Project architecture: complete**
- **Phase 2 — Database design and typed Firebase foundation: complete**
- **Phase 3 — Authentication: next**

The repository now contains:

- Feature-first Clean Architecture.
- Riverpod dependency injection and application state.
- GoRouter navigation infrastructure.
- Premium adaptive light/dark design system.
- Environment/flavor configuration and Firebase App Check bootstrap.
- Typed Firestore DTOs, domain models, mappers, and `withConverter` references.
- Firebase repository implementations for profiles, sports catalogs, events, places, challenges, marketplace discovery, app configuration, and feature flags.
- Composite indexes for implemented production queries.
- Firestore and Storage rules with field-level invariants and deny-by-default fallbacks.
- Emulator rules tests and deterministic seed data.
- TypeScript Cloud Functions foundation and migration conventions.
- Product, architecture, screen, model, service, widget, schema, deployment, and phase documentation.

## Architecture

ReeMove uses feature-first vertical slices. Every feature owns its presentation, application, domain, and data code. Cross-cutting code lives in `lib/core`; app composition lives in `lib/app`.

```text
presentation -> application -> domain <- data
                         repositories
```

Firebase SDK types stay in the data layer. Domain entities use plain Dart values. Riverpod wires repository contracts to Firebase implementations. Widgets never call Firebase directly.

## Requirements

- Flutter 3.44 or newer
- Dart 3.10 or newer
- Node.js 22
- Java 21 or newer for the current Firebase Emulator Suite
- Firebase CLI / FlutterFire CLI
- Separate Firebase projects for development, staging, and production

## First-time setup

```bash
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID
cp .firebaserc.example .firebaserc

cd functions
npm install
npm run lint
npm run build
cd ..

cd firebase_tests
npm install
cd ..
```

Run development mode:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=ENABLE_APP_CHECK=false
```

## Local Firebase verification

```bash
npm run test:rules
npm run seed:emulator
```

Deploy only after the Flutter suite, Functions build, and emulator rules tests pass:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

## Documentation index

- `docs/IMPLEMENTATION_ROADMAP.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/SCREEN_CATALOG.md`
- `docs/FIREBASE_SCHEMA.md`
- `docs/DATABASE_IMPLEMENTATION.md`
- `docs/DATA_MIGRATIONS.md`
- `docs/MODEL_CATALOG.md`
- `docs/SERVICE_CATALOG.md`
- `docs/WIDGET_CATALOG.md`
- `docs/ARCHITECTURE_DECISIONS.md`
- `docs/PHASE_TRACKER.md`
- `docs/PHASE_2_COMPLETION.md`
- `docs/DEPLOYMENT_GUIDE.md`
