# Firebase staging services matrix

Project: `reemove-staging` only. See `docs/FIREBASE_STAGING_SETUP.md` for console steps.

| Service | Required | Code | Stage 5 auto | Manual / blocked |
|---------|----------|------|--------------|------------------|
| Auth Email/Google/Apple | Yes | Yes | No — Auth config missing without Console Get started | Yes — Get started + providers |
| Firestore | Yes | Yes | **Done** — API on, DB `(default)` @ `eur3` | Rules deploy later |
| Storage | Yes | Yes | **Blocked** — billing required | Yes after Blaze decision |
| RTDB | Yes | Yes | **Done** — `europe-west1` default instance | dart-define URL; rules later |
| Functions | Yes | Yes | No — deploy forbidden | Later |
| FCM | Yes | Yes | Apps exist | APNs deferred |
| Remote Config | Yes | Yes | **Done** — 16 params published via REST | Console verify optional |
| App Check | Later | Yes | No — enforce forbidden | Register only / monitor |
| Analytics | Optional | Yes | No | Optional |
| Crashlytics | Yes (mobile) | Yes | API enabled + FlutterFire symbol scripts | Open Console once |
| Performance | Recommended | Yes | No | Optional |
| Hosting | No | No | Skip | Skip |

FlutterFire: Android/iOS/Web apps + `lib/firebase_options_staging.dart` (includes RTDB `databaseURL`). Production: **0 apps**.
