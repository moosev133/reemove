# ReeMove Closed Beta — Progress Log

**Last updated:** 2026-08-06 (iOS pod install + deployment target fix)

## Completed
- **Android staging AAB:** `bash scripts/build_android_staging.sh` succeeded
  - Path: `reemove_app/build/app/outputs/bundle/release/app-release.aab`
  - Size: **56,777,365 bytes (56.8 MB)**
  - Signed with debug keystore (no `android/key.properties` — not Play-upload ready)
- **Feature-flag gating:** `ReleaseFeatureGate` in router + Discover/Create/Auth UI
- **Safety:** Message report reason sheet; DM block from conversation
- **Tests:** Flutter **218/218** (includes picker/upload regression tests); Functions **154/154**
- **Web:** Staging build validated; picker timeout edge case fixed (Choosing/Reading/Validating states)
- **Trainer upload diagnostics:** Split picker/upload states, byte counters, timeout after transfer starts, cancel, retry.
- **Regression tests:** `profile_verification_screen_test.dart` **15/15**; `platform_verification_evidence_picker_test.dart` **6/6**
- **Rules re-run:** `npm run test:rules` passed **65/65** (Java 21 emulators).
- **iOS CocoaPods:** `pod install` succeeded after raising deployment target to **iOS 15.0** (Firebase SDK 12 requirement)
  - 70 pods installed; `Podfile.lock` + `Pods/` generated locally
  - Build script updated: UTF-8 locale, 5 GiB disk preflight, `pod install`, Xcode check

## Prior session (code complete, manual QA pending)
- Trainer PNG web picker + immediate UI states
- Group moderation delete ACL fix
- Integration 75/75, Rules 65/65 (prior run)

## Manual QA status
- P0 manager delete: **PASS** (owner/admin can delete member messages)
- P0 trainer PNG upload: **Re-test pending** (picker timeout fix deployed to staging web)

## Owner-blocked
- P0 remaining manual QA: Trainer PNG upload to Uploaded + draft save + Pending submit
- Play upload signing: `android/key.properties` + upload keystore
- **iOS build:** Full **Xcode.app** required (`xcode-select` currently points to Command Line Tools only)
- Firebase platform plist/json (gitignored) via FlutterFire

## Validated beta build paths
| Platform | Status |
|----------|--------|
| Web staging | ✅ `flutter build web` |
| Android AAB (staging, debug-signed) | ✅ `scripts/build_android_staging.sh` |
| iOS no-codesign | ⏳ Owner full Xcode install + `bash scripts/build_ios_staging_nocodesign.sh` |
