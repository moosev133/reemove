# Firebase Production Setup — `reemove-production`

**Scope:** Production project only. Do **not** modify `reemove-staging` while applying these steps.  
**Do not deploy** rules, indexes, Functions, or Hosting in Stage 6.  
**Related:** `docs/FLUTTERFIRE_PRODUCTION.md`.

---

## Stage 6 status

| Item | Status |
|------|--------|
| FlutterFire Android / iOS / Web apps | **Done** — `com.reemove.app` |
| `lib/firebase_options_production.dart` | **Done** — RTDB URL + expected Storage bucket name |
| Bootstrap `APP_FLAVOR=production` | **Done** → `ProductionFirebaseOptions` |
| Firestore `(default)` | **Ready** — Native @ **`eur3`** |
| Realtime Database | **Ready** — `europe-west1` |
| Remote Config | **Published** — 16 params (same template as staging) |
| Crashlytics API | **Enabled** |
| Cloud Storage bucket | **Blocked** — production billing not enabled |
| Authentication | **Blocked** — Console **Get started** required |
| Staging project | **Untouched** (3 apps remain) |

### Production resource IDs

| Resource | Value |
|----------|-------|
| Project | `reemove-production` (`1063937415105`) |
| Firestore | `projects/reemove-production/databases/(default)` @ `eur3` |
| RTDB | `https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app` |
| Storage (expected) | `reemove-production.firebasestorage.app` (**bucket not created yet**) |

---

## STOP — owner actions required

Complete in [Firebase Console](https://console.firebase.google.com/) → **ReeMove Production** (`reemove-production`).

### 1. Enable billing (Blaze) for production — required for Storage

Mirror staging: Storage default bucket creation needs a billing account linked to `reemove-production`.  
After billing is on: Build → **Storage** → Get started → location **`europe-west1`** (match staging).  
Do **not** deploy `storage.rules` yet.

### 2. Authentication — Get started + providers

1. Build → **Authentication** → **Get started**
2. Enable **Email/Password**
3. Enable **Google** (support email = owner) → copy **Web client ID** into local `dart_defines/prod.json` as `GOOGLE_SERVER_CLIENT_ID`
4. Enable **Apple** (needs Apple Developer Services ID / Team ID / Key / capability for `com.reemove.app`)

After Google is enabled, reply so debug **SHA-1/SHA-256** can be registered on the production Android app (same flow as staging), then regenerate / refresh OAuth client fields in configs.

### 3. Optional — open Crashlytics once

Build → **Crashlytics** for the Android/iOS apps if prompted. First crash/symbol upload finishes onboarding. APNs still deferred.

---

## Explicitly out of scope (Stage 6)

- Changing staging
- `firebase deploy` (rules, functions, hosting, indexes)
- App Store / Play Store publish
- Maps, App Check enforcement, APNs
