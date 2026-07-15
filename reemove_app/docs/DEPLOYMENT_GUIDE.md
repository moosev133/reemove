# Deployment guide foundation

## Environment topology

Create three isolated Firebase projects:

- `reemove-dev`
- `reemove-staging`
- `reemove-prod`

Do not share Authentication users, Firestore data, Storage buckets, Analytics streams, App Check settings, OAuth client registrations, or signing configuration between environments.

## FlutterFire configuration

Run `flutterfire configure` separately for each environment. `lib/firebase_options.dart` and native Firebase configuration files are intentionally absent because they must be generated from the owner's real projects.

Generate native platform folders and install dependencies:

```bash
./scripts/bootstrap_project.sh
```

Then run:

```bash
flutterfire configure --project YOUR_PROJECT_ID
```

## Authentication configuration

Complete `AUTHENTICATION_SETUP.md` before testing production authentication. At minimum:

- Enable Email/Password, Google, and Apple.
- Register Android SHA-1/SHA-256 fingerprints for every signing key.
- Configure the iOS reversed client ID URL scheme.
- Enable Sign in with Apple and provide Firebase with Apple credentials.
- Configure email-verification and password-reset templates/domains.
- Pass `GOOGLE_SERVER_CLIENT_ID` and `FIREBASE_FUNCTIONS_REGION` at build time.
- Keep `ENABLE_ANALYTICS=false` until privacy/consent/store configuration is approved.
- Configure Firestore TTL for `rate_limits.expiresAt`.

## App Check

- Development: debug providers with registered debug tokens.
- Android production: Play Integrity.
- Apple production: App Attest with DeviceCheck fallback.
- Web production: reCAPTCHA v3.

Enable enforcement only after staging traffic confirms that every supported client sends valid tokens.

## Pre-deployment verification

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
npm run verify:backend
```

`npm run verify:backend` includes Functions lint/build/unit tests and Firestore/Storage Rules tests. Java 21 and Firebase emulator binaries are required.

## Firebase deployment

```bash
firebase use staging
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

After staging validation, promote the same reviewed commit to production. Never edit production rules or indexes manually without committing the exact change back to source control.

## Seed data

The checked-in seed workflow is emulator-only:

```bash
npm run seed:emulator
```

It starts Auth and Firestore emulators, creates the deterministic demo identity, and writes matching Firestore records. It refuses to run without emulator host variables or against a project ID that does not start with `demo-`.

## Phase 3 authentication release gates

- Email registration creates an Auth identity and atomically provisions the ReeMove account.
- Username collision behavior is tested under concurrent requests.
- Verification and reset action links use approved domains.
- Google works with debug, staging, and production signing identities.
- Apple works on a physical device and after credential rotation.
- Federated cancellation does not show an application error.
- Provider linking updates one Firebase/ReeMove identity and rejects credentials owned by another account.
- Account-wide session revocation requires recent authentication and is verified across two devices.
- Account deletion requires recent authentication, releases the username, and can recover through the scheduled retry function.
- The Firebase project has billing/scheduler support required by `retryAccountDeletions`.
- Firestore clients cannot create profiles, usernames, private records, rate-limit records, audit records, or deletion records.
- App Check is monitored in staging before enforcement.
- Auth and account-lifecycle events are visible in server audit/logging without passwords, raw credentials, or tokens; identity references are limited to operational UID/target IDs.
- Authentication analytics contains only approved action/provider categories and is explicitly enabled per environment.

## Mobile release gates

- Static analysis and all automated tests pass.
- Firestore and Storage emulator tests pass.
- Indexes are deployed before client queries are released.
- Crash-free staging target is met.
- Accessibility and RTL audits are complete.
- Privacy policy, terms, account deletion, data export, and age handling are reviewed.
- Store privacy declarations match actual collection behavior.
- API keys and OAuth credentials are restricted.
- Monitoring, rollback, backups, and incident ownership are assigned.

A complete store-specific operational runbook is delivered in Phase 16.
