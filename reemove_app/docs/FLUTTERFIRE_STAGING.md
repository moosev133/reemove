# FlutterFire staging configuration (Stage 4)

## Project

| Alias | Project ID |
|-------|------------|
| `staging` | `reemove-staging` |
| `production` | `reemove-production` (alias only — not configured in Stage 4) |

Local `.firebaserc` is gitignored. Copy from `.firebaserc.example`.

## Apps registered in `reemove-staging`

| Platform | Package / bundle | Notes |
|----------|------------------|-------|
| Android | `com.reemove.app` | Dedicated Android app |
| iOS | `com.reemove.app` | Dedicated iOS app |
| macOS | `com.reemove.app` | Shares Apple app / plist with iOS (same bundle ID) |
| Web | ReeMove web app | Dedicated web app |

## Separation model

| Flavor (`APP_FLAVOR`) | Dart options | Native files |
|-----------------------|--------------|--------------|
| `staging` | `lib/firebase_options_staging.dart` → `StagingFirebaseOptions` | Optional under `*/config/staging/` or `android/app/src/staging/` (gitignored) |
| `development` | None (bare `Firebase.initializeApp()` / emulators) | None required |
| `production` | Not generated yet | Not generated yet |

Production never imports staging options. Default compile flavor remains `development`.

## Run staging (web)

```bash
flutter run -d chrome \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=false
```

Or copy `dart_defines/staging.json.example` → `dart_defines/staging.json` and use `--dart-define-from-file=dart_defines/staging.json`.

## What Stage 4 does / does not do

**Done:** app registration, staging Dart options, bootstrap wiring, CLI aliases.

**Not done:** Auth/Firestore/Storage/RTDB/App Check/Maps/Functions product setup, rules deploy, production FlutterFire.
