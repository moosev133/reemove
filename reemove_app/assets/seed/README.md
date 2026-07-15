# Emulator seed dataset

The canonical deterministic seed data lives in:

- `functions/src/seed/seedAuth.ts`
- `functions/src/seed/seedData.ts`
- `functions/src/seed/seedFirestore.ts`

It includes two matching Firebase Auth Emulator identities: one completed athlete and one account that enters the Phase 4 onboarding flow. Their username reservations, public profiles, private profile/consent/preferences/onboarding records, three supported sports, places, event, challenge, marketplace listing, app configuration, and feature flags are seeded consistently.

For interactive development:

```bash
npm run emulators:start
npm run seed:running-emulators
```

Run those commands in separate terminals. `npm run seed:emulator` is the one-shot CI/smoke workflow that starts Auth/Firestore, seeds them, and exits.

The seed scripts refuse to run unless emulator host variables are present and the project ID begins with `demo-`, preventing accidental production writes.
