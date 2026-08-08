# Owner Action Checklist — Closed Beta

Items that **cannot** be completed in the repository alone.

## P0 — Manual staging QA (blocking beta sign-off)

| Action | Verification |
|--------|--------------|
| Trainer PNG upload: Selected → Uploaded → draft restore → Pending | Hard-refresh http://127.0.0.1:7357 |
| Group owner **Delete message (manager)** on member message | ✅ Manually verified PASS (2026-08-06) |

## P0 — Build environment (blocking mobile beta artifacts)

| Action | System | Details |
|--------|--------|---------|
| **Free ≥10 GiB disk** before Android AAB build | Local machine | Current agent environment had ~2 GiB; Gradle needs ~5–10 GiB |
| Run Android staging build | Local / CI | `cd reemove_app && bash scripts/build_android_staging.sh` |
| Install **CocoaPods** (`gem install cocoapods` or brew) | macOS | ✅ CocoaPods 1.17.0 installed |
| Run `pod install` in `reemove_app/ios/` | macOS | ✅ Succeeded (iOS 15 deployment target) |
| Install **full Xcode.app** from App Store | macOS | Required — `xcodebuild` unavailable (CLT only) |
| Select Xcode developer dir | macOS | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |
| Run iOS no-codesign validation | macOS + Xcode | `cd reemove_app && bash scripts/build_ios_staging_nocodesign.sh` |
| Materialize Firebase platform files (gitignored) | FlutterFire | See `firebase/staging/README.md` — `GoogleService-Info.plist`, `google-services.json` |

## P1 — Distribution

| Action | System |
|--------|--------|
| Android upload keystore + `android/key.properties` | Play Console |
| Play closed testing track + tester emails | Google Play |
| Apple Developer + distribution cert + provisioning | App Store Connect |
| `gcloud auth application-default login` | Staging QA scripts |

## P1 — Firebase / security

| Action | Notes |
|--------|-------|
| App Check monitor → enforce when ready | `reemove_app/docs/APP_CHECK_ROLLOUT.md` |
| Admin custom claims for verification reviewers | Firebase Auth |
| Set Remote Config flags for beta | `ai_modules_enabled`, `messaging_enabled`, etc. |

## P2 — Legal / store

- Privacy policy URL live
- Terms of service for beta testers

---

## Staging web build

```bash
cd reemove_app
flutter build web \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=USE_FIREBASE_EMULATORS=false
cd build/web && python3 -m http.server 7357 --bind 127.0.0.1
```

## Android AGP configuration (repository — done)

`android/gradle.properties` already sets:
- `android.newDsl=false`
- `android.builtInKotlin=false`

No further AGP 9 migration needed for current Flutter 3.41 toolchain.

## JDK for emulator tests

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
cd reemove_app && npm run test:integration
```
