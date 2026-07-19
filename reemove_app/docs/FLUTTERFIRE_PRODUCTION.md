# FlutterFire production configuration (Stage 6)

## Project

| Alias | Project ID |
|-------|------------|
| `staging` | `reemove-staging` (unchanged) |
| `production` | `reemove-production` |

Local `.firebaserc` is gitignored. Copy from `.firebaserc.example`.

## Apps registered in `reemove-production`

| Platform | Package / bundle | App ID |
|----------|------------------|--------|
| Android | `com.reemove.app` | `1:1063937415105:android:4070ea54830f2943024140` |
| iOS | `com.reemove.app` | `1:1063937415105:ios:89d7a13be01a74dd024140` |
| macOS | `com.reemove.app` | Shares Apple app with iOS |
| Web | ReeMove web | `1:1063937415105:web:b524c00175433b7a024140` |

## Separation model

| Flavor (`APP_FLAVOR`) | Dart options | Native files (gitignored) |
|-----------------------|--------------|---------------------------|
| `staging` | `lib/firebase_options_staging.dart` → `StagingFirebaseOptions` | `*/staging/` |
| `production` | `lib/firebase_options_production.dart` → `ProductionFirebaseOptions` | `*/production/` |
| `development` | None (bare `Firebase.initializeApp()` / emulators) | None required |

Staging never imports production options and vice versa. Default compile flavor remains `development`.

## Run production (local smoke only — do not ship)

```bash
flutter run -d chrome \
  --dart-define=APP_FLAVOR=production \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define=FIREBASE_DATABASE_URL=https://reemove-production-default-rtdb.europe-west1.firebasedatabase.app
```

Or copy `dart_defines/prod.json.example` → `dart_defines/prod.json` and use `--dart-define-from-file=dart_defines/prod.json`.

## What Stage 6 does / does not do

**Done:** production app registration, Dart options, bootstrap wiring, Firestore + RTDB + Remote Config on production, staging left intact.

**Not done / owner:** Auth Get started + providers, Storage bucket (billing), Google SHA + OAuth client ID, Apple Developer, APNs, App Check enforcement, rules/Functions/Hosting deploy, store publish.
