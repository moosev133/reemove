# Sports hubs setup and release gates

## Firebase deployment

Deploy the Phase 9 backend as one coordinated release:

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Storage and Realtime Database rules remain part of the cumulative application release even though Phase 9 adds no new client-upload path:

```bash
firebase deploy --only storage,database
```

## Required catalog records

Create enabled `sports/{sportId}` documents for `football`, `gym`, and `running`. Their IDs are stable API identifiers and must never be localized. Localized display names belong in `localizedNames`.

Seed or import reviewed records for:

- `places`
- `teams` and `teams/{teamId}/members`
- `events` and `events/{eventId}/attendees`
- `trainer_profiles`
- `trainer_services`
- `leaderboards`
- verified `activities`

Use the emulator seed before production import:

```bash
npm run emulators:start
npm run seed:running-emulators
```

## Scheduler and Functions

The Firebase project must support scheduled Functions. Confirm `refreshSportLeaderboards` is deployed in the configured primary region and runs every six hours. Monitor execution count, query size, failures, and leaderboard freshness.

Only controlled administrator tooling may call `rebuildSportLeaderboardsNow`. Never expose administrator claims or callable access from normal account settings.

## Trainer prerequisites

A trainer service can be published only when the account:

- has an active profile;
- has `isVerified == true`;
- has `verificationType` equal to `trainer` or `business`;
- supplies a supported sport, service type, delivery mode, duration, and positive ISO-currency price.

Keep verification review disabled for external users until the operational process in `PROFILE_VERIFICATION_SETUP.md` is active.

## Pre-release checks

- Deploy all Phase 9 indexes before releasing the client.
- Pass Functions lint, strict TypeScript build, policy tests, Flutter analysis/tests, and Firebase emulator Rules tests.
- Test each launch sport with populated and empty catalogs.
- Test open, approval-required, invite-only, full, pending, manager approval/rejection, and owner community states.
- Test event attending, waitlisting, cancellation, automatic earliest-waitlist promotion, ended-event, and retry/idempotency behavior on two devices.
- Verify direct client writes cannot forge memberships, attendance, counters, trainer services, activities, or rankings.
- Verify pending community members and another user's event attendance/activity records are not readable.
- Test verified trainer and non-trainer publication attempts.
- Verify scheduled rankings with zero, one, tied, and more-than-50 participants.
- Confirm pricing displays use currency minor units and locale-aware formatting in the final localized build.
- Review catalog moderation and data-import ownership before production population.

## Phase 10 handoff

Before nearby maps are enabled, place and event records must contain valid `GeoPoint`, geohash, country/locality metadata, moderation state, and public visibility. Route geometry and map-provider data are added in Phase 10 without changing the Phase 9 domain contracts.
