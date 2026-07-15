# Emulator seed dataset

The canonical deterministic seed data lives in:

- `functions/src/seed/seedAuth.ts`
- `functions/src/seed/seedData.ts`
- `functions/src/seed/seedFirestore.ts`

It includes a matching Firebase Auth Emulator identity, username reservation,
public profile, owner-private profile and consent records, the three supported
sports, public places, one event, one challenge, one marketplace listing, app
configuration, and feature flags.

Run from the repository root:

```bash
npm run seed:emulator
```

The Auth and Firestore scripts refuse to run unless their emulator host
variables are present and the project ID begins with `demo-`, preventing
accidental production writes.
