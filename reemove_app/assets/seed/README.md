# Emulator seed dataset

The canonical seed data is typed TypeScript in `functions/src/seed/seedData.ts`.
It includes the three fully supported sports, sample public places, one event,
one challenge, one marketplace listing, app configuration, feature flags, and a
demo athlete profile.

Run from the repository root:

```bash
npm run seed:emulator
```

The script refuses to run unless `FIRESTORE_EMULATOR_HOST` is present and the
project ID begins with `demo-`, preventing accidental production writes.
