# Firebase staging services matrix

Project: `reemove-staging` only. See `docs/FIREBASE_STAGING_SETUP.md`.

| Service | Required | Code | Stage 5 | Notes |
|---------|----------|------|---------|-------|
| Auth Email | Yes | Yes | **Done** | Enabled |
| Auth Google | Yes | Yes | **Done** | OAuth + debug SHA + dart-define |
| Auth Apple | Yes | Yes | **Provider on** | Apple Developer / code-flow later |
| Firestore | Yes | Yes | **Done** | `(default)` @ `eur3` |
| Storage | Yes | Yes | **Done** | `reemove-staging.firebasestorage.app` @ `EUROPE-WEST1` |
| RTDB | Yes | Yes | **Done** | `europe-west1` |
| Functions | Yes | Yes | Later | Deploy forbidden in Stage 5 |
| FCM | Yes | Yes | Apps exist | APNs deferred |
| Remote Config | Yes | Yes | **Done** | 16 params via REST |
| App Check | Later | Yes | Skip enforce | |
| Analytics | Optional | Yes | Optional | |
| Crashlytics | Yes (mobile) | Yes | API + symbol scripts | |
| Performance | Recommended | Yes | Optional | |
| Hosting | No | No | Skip | |

FlutterFire: Android/iOS/Web + `lib/firebase_options_staging.dart`. Production: **0 apps**.
