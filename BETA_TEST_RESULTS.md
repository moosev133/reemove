# ReeMove Closed Beta — Test Results

## 2026-08-06 — iOS staging no-codesign build attempt

| Command | Environment | Result | Notes |
|---------|-------------|--------|-------|
| `df -h /tmp/reemove-c2-indep` | macOS | **18 GiB avail** | Above 5 GiB script minimum |
| `pod install` (ios/) | CocoaPods 1.17.0, LANG=UTF-8 | **Success** | After iOS deployment target 13 → **15.0**; 70 pods installed |
| `bash scripts/build_ios_staging_nocodesign.sh` | Flutter 3.41.2, staging defines | **Blocked (exit 5)** | Full Xcode not installed; `xcode-select` → Command Line Tools only |
| Expected artifact (when Xcode available) | — | `build/ios/iphoneos/Runner.app` | `--no-codesign`; script prints path on success |

### Repository fixes applied for iOS
- `ios/Podfile` + `Runner.xcodeproj`: minimum deployment target **15.0** (Firebase SDK 12 / FlutterFire requirement)
- `ios/Flutter/Debug.xcconfig` + `Release.xcconfig`: include Pods xcconfig
- `scripts/build_ios_staging_nocodesign.sh`: UTF-8 locale, disk preflight, `pod install`, Xcode availability check

## 2026-08-06 — Android staging AAB build

| Command | Environment | Result | Notes |
|---------|-------------|--------|-------|
| `df -h /` | macOS | **8.8 GiB avail** | Below 10 GiB user threshold; above script 5 GiB minimum |
| `bash scripts/build_android_staging.sh` | Flutter 3.41.2, Java 21, staging defines | **Success** | Gradle ~951s; debug signing (no `key.properties`) |
| Output AAB | — | `build/app/outputs/bundle/release/app-release.aab` | **56,777,365 bytes (56.8 MB)** |
| `flutter test test/features/profile/profile_verification_screen_test.dart` | local | **15/15 pass** | Delayed picker, slow read, timeout/retry/cancel coverage |
| `flutter test test/features/profile/platform_verification_evidence_picker_test.dart` | local | **6/6 pass** | No timeout while choosing; read timeout; validation messages |
| `npm run test:rules` | Java 21 + emulators | **65/65 pass** | Re-run after upload-state changes |

## 2026-08-06 session 2

| Command | Result | Notes |
|---------|--------|-------|
| `flutter test` | **205/205 pass** | +3 release feature gate tests |
| `npm run test:functions` | **154/154 pass** | |
| `flutter build web` (staging) | **Success** | Validated beta web path |
| `bash scripts/build_android_staging.sh` | **Skipped** (earlier) | Preflight: only ~2 GiB free |
| `flutter build ios --no-codesign` | **Blocked** | Full Xcode.app required (CocoaPods + pod install now pass) |

## 2026-08-06 session 1 (prior)

| Command | Result |
|---------|--------|
| `flutter test` | 202/202 |
| `npm run test:integration` | 75/75 |
| `npm run test:rules` | 65/65 |

## Pending rerun
- `npm run test:rules` (needs `firebase_tests` npm install)
- `npm run test:integration` (Java 21 + emulators)
- `bash scripts/build_ios_staging_nocodesign.sh` (needs **full Xcode.app** — CocoaPods + pod install complete)
