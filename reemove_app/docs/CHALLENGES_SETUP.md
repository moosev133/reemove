# Challenges setup and release guide

## Prerequisites

- Phase 1–10 Firebase resources are deployed.
- Firestore, Storage, Authentication, Functions, App Check, Cloud Scheduler, and FCM are enabled.
- Node.js 22 and Java 21 are available in CI/staging.
- Flutter 3.44+ and Dart 3.10+ are available for client verification.

## Deploy in order

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
firebase deploy --only functions
```

Deploy all Phase 11 challenge Functions, including scheduled jobs. Confirm their region matches `FIREBASE_FUNCTIONS_REGION`.

## Seed development or staging

Start emulators and seed the deterministic dataset:

```bash
npm run emulators:start
npm run seed:running-emulators
```

Seed data includes safe running, gym, and football challenges, participants, leaderboards, verified activities, badge catalog, and reward catalog.

## Proof review IAM

The Functions runtime identity needs only the minimal permission required to sign short-lived Cloud Storage URLs for the project bucket. Do not make `challenge_proofs` public. Verify:

- URLs expire after five minutes;
- only creator/admin/eligible community manager can request them;
- every request creates an audit record;
- application logs do not print the URL;
- proof retention/deletion follows the privacy policy.

## Scheduler and reminders

Verify each schedule in staging:

- weekly challenge generation;
- leaderboard refresh;
- challenge expiration finalization;
- participant reminders.

Confirm scheduler identity, retries, idempotency, timezone handling, monitoring alerts, and FCM invalid-token cleanup. Reminders must respect participant opt-in and notification preferences.

## Security verification

```bash
npm --prefix firebase_tests ci
npm run test:rules
npm --prefix functions run test:unit
```

Test at minimum:

- public versus draft/private challenge reads;
- owner-only participation/history/rewards;
- manager-only submission review;
- denied direct writes to all challenge state;
- proof path/content-type/size/metadata enforcement;
- age eligibility and blocked users;
- target/unit/daily-cap safety bounds;
- verified activity ownership/window/metric validation;
- duplicate activity and reward claim retries;
- signed proof URL authorization and expiry;
- scheduler idempotency and reminder opt-out.

## AI-assisted generation

The Phase 11 generator intentionally uses curated reviewed templates. Do not connect a general-purpose model directly. External model generation remains disabled until Phase 14 provides:

- provider-neutral gateway and structured schemas;
- prompt/version control;
- age-aware safety filters;
- evaluation datasets and regression thresholds;
- human review and emergency kill switch;
- quotas, abuse controls, cost telemetry, and audit logs.

## Production gate

Production enablement requires passing Flutter analysis/tests/builds, all Firebase emulator tests, physical-device notification tests, accessibility review, scheduler monitoring, proof-retention review, abuse escalation, and rollback/kill-switch verification.
