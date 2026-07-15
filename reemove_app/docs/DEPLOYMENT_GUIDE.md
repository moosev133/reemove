# Deployment guide foundation

## Environment topology

Create three isolated Firebase projects:

- `reemove-dev`
- `reemove-staging`
- `reemove-prod`

Do not share Authentication users, Firestore data, Storage buckets, Analytics streams, App Check settings, or signing configuration between environments.

## FlutterFire configuration

Run `flutterfire configure` separately for each environment. `lib/firebase_options.dart` and native Firebase configuration files are intentionally ignored because they must come from the owner's real Firebase projects.

## App Check

- Development: debug providers with registered debug tokens.
- Android production: Play Integrity.
- Apple production: App Attest with DeviceCheck fallback.
- Web production: reCAPTCHA v3.
- Enable enforcement only after valid staging traffic is visible for every supported client.

## Pre-deployment verification

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage

cd functions
npm ci
npm run lint
npm run build
cd ..

cd firebase_tests
npm install
cd ..
npm run test:rules
```

## Firebase deployment

```bash
firebase use staging
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

After staging validation, promote the same reviewed commit to production. Never edit production rules or indexes manually in the console without committing the exact change back to source control.

## Seed data

The checked-in seed script is emulator-only:

```bash
npm run seed:emulator
```

It refuses to run without `FIRESTORE_EMULATOR_HOST` and a `demo-` project ID. Production data must use separately reviewed migration tooling.

## Mobile release gates

- Static analysis and all automated tests pass.
- Firestore and Storage emulator tests pass.
- Indexes are deployed before the client query release.
- Crash-free staging target is met.
- Accessibility and RTL audits are complete.
- Privacy policy, terms, account deletion, data export, and age handling are reviewed.
- Store privacy declarations match actual collection behavior.
- App Check enforcement and API key restrictions are verified.
- Monitoring, rollback, and incident ownership are assigned.

A complete store-specific deployment runbook is delivered in Phase 16.
