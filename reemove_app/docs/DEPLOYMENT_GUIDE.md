# Deployment guide foundation

## Environment topology

Create three isolated Firebase projects:

- `reemove-dev`
- `reemove-staging`
- `reemove-prod`

Do not share Authentication users, Firestore data, Storage buckets, Analytics streams, or App Check settings between environments.

## FlutterFire configuration

Run `flutterfire configure` separately for each build environment and store generated platform files in the secure CI system. `lib/firebase_options.dart` is intentionally ignored in this starter package because it must be generated from the owner's real Firebase project.

## App Check

- Development: debug providers with registered debug tokens.
- Android production: Play Integrity.
- Apple production: App Attest with DeviceCheck fallback.
- Web production: reCAPTCHA v3 provider.
- Enable enforcement only after observing valid traffic and verifying every production build.

## Firebase deployment

```bash
firebase use staging
firebase emulators:exec "flutter test"
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Promote the same reviewed commit from staging to production.

## Mobile release gates

- Static analysis and all automated tests pass.
- Firestore/Storage rules tests pass in emulator.
- Crash-free staging session target met.
- Accessibility audit complete.
- Privacy policy, terms, account deletion, data export, and age handling reviewed.
- App Store and Play declarations match actual data collection.
- App Check enforcement and API restrictions verified.
- Monitoring, rollback, and incident owner assigned.

A complete store-specific deployment runbook is delivered in Phase 16.
