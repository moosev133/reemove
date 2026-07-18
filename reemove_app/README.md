# ReeMove

ReeMove is a production-oriented Flutter and Firebase sports social network. The product combines social content, activity tracking, nearby discovery, sports communities, events, challenges, marketplace features, messaging, notifications, and a server-side AI coach layer.

## Current implementation status

**Phases 1–16 are complete** in this package (`reemove_app/`).

| Area | Status |
|------|--------|
| Architecture, DI, routing, auth, onboarding | Complete |
| Feed, messaging, profile, sports hubs, nearby/maps UI | Complete |
| Challenges, marketplace, notifications, AI (Functions) | Complete |
| Quality gates, release workflows, production docs | Complete |
| Local validation (analyze, unit, rules, web, Android debug) | Pass |

**Not store-ready yet.** Owner configuration remains: real application IDs, Firebase projects / FlutterFire files, Maps keys, signing, App Check enforcement, hosted deep-link files, and store listings. See `docs/OWNER_ACTION_CHECKLIST.md` and `docs/RELEASE_ENGINEERING_REPORT.md`.

Native deep-link and Maps **scaffolding** is applied (App Links intent filters, iOS associated domains, Maps placeholders). Verified domain hosting, restricted API keys, and final bundle IDs still require the owner. Re-run after ID changes:

```bash
python3 scripts/configure_deep_links.py --host YOUR_LINKS_HOST
python3 scripts/configure_google_maps.py
```

## Architecture

```text
presentation -> application -> domain <- data
                         repositories
```

Firebase and platform SDKs remain implementation details in the data layer. Riverpod composes dependencies. Widgets never call Firebase directly. Single GoRouter, single Firebase provider graph.

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

- `docs/ENVIRONMENT_AND_FIREBASE_SETUP.md`
- `docs/AUTHENTICATION_SETUP.md`
- `docs/GOOGLE_MAPS_SETUP.md`
- `docs/DEEP_LINK_SETUP.md`
- `docs/OWNER_ACTION_CHECKLIST.md`

## Local emulators

```bash
npm run emulators:start
npm run seed:running-emulators
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Emulator-only users:

```text
athlete@demo.reemove.app / ReeMoveDemo123!
newcomer@demo.reemove.app / ReeMoveDemo123!
```

Never use these credentials outside the local `demo-reemove` emulator project.

## Verification

```bash
python3 scripts/validate_repository.py
python3 scripts/scan_secrets.py
npm run verify:backend
flutter analyze
flutter test
```

## Production run (after owner config)

```bash
flutter run --release \
  --dart-define-from-file=dart_defines/prod.json
```

## Documentation

Start here for release:

- `docs/RELEASE_ENGINEERING_REPORT.md`
- `docs/FINAL_PRODUCTION_AUDIT.md`
- `docs/OWNER_ACTION_CHECKLIST.md`
- `docs/MASTER_DEPLOYMENT_PLAN.md`
- `docs/CI_CD_RELEASE_PIPELINE.md`
- `docs/PHASE_TRACKER.md`
