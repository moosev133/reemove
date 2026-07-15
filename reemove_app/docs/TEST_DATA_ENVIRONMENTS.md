> **Production merge note:** Emulator project id is `demo-reemove`. Firestore emulator listens on **8180** (not 8080). Functions region is **europe-west1**. Rules tests live in `firebase_tests/` (not `firebase/rules-tests/`).

# Test Data and Environment Management

## Projects

Use separate Firebase projects for development, staging, and production. Test automation must fail if a production project ID is detected.

## Synthetic users

Create deterministic roles:

- Public athlete
- Private athlete
- Minor user
- Adult user
- Trainer
- Organizer
- Marketplace seller
- Marketplace buyer
- Moderator/admin
- Blocked pair
- Group member and non-member

Do not use real names, phone numbers, personal photos, private messages, precise home locations, or real health data.

## Seed principles

- Fixed IDs make assertions stable.
- Timestamps are relative to a test clock.
- Media uses small licensed/generated fixtures.
- Nearby coordinates are synthetic and coarse.
- Each test owns or resets its data.
- Tests can run repeatedly without duplicate side effects.

## App Check

Use debug providers/tokens only in local and CI environments. Release builds must reject debug configuration. Monitor metrics before enabling or tightening enforcement in staging/production.

## Cleanup

CI jobs use fresh emulators. Staging tests tag resources with `testRunId` and delete them after execution. A scheduled cleanup removes expired test resources but never substitutes for per-run cleanup.

## Configuration

Required environment variables are documented in `.env.test.example`. Do not commit real secrets.
