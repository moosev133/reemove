# Firebase staging services matrix

Project: `reemove-staging` only. See `docs/FIREBASE_STAGING_SETUP.md` for console steps.

| Service | Required | Code | Auto (CLI Stage 5) | Manual console |
|---------|----------|------|--------------------|----------------|
| Auth Email/Google/Apple | Yes | Yes | No | Yes |
| Firestore | Yes | Yes | No (API was disabled; gcloud N/A) | Yes — enable API + create DB |
| Storage | Yes | Yes | No | Yes |
| RTDB | Yes | Yes | No | Yes + dart-define URL |
| Functions | Yes | Yes | No — deploy forbidden | Later |
| FCM | Yes | Yes | Apps exist | Yes (APNs deferred) |
| Remote Config | Yes | Yes | No — deploy forbidden | Yes — publish template params |
| App Check | Later | Yes | No — enforce forbidden | Register only / monitor |
| Analytics | Optional | Yes | No | Optional |
| Crashlytics | Yes (mobile) | Yes | No | Yes |
| Performance | Recommended | Yes | No | Yes |
| Hosting | No | No | Skip | Skip |

Already configured before Stage 5: FlutterFire Android/iOS/Web apps + `lib/firebase_options_staging.dart`.
