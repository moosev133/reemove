# Owner action checklist — ReeMove production

Use this list to finish launch. Tags:

| Tag | Meaning |
|-----|---------|
| **Completed by Cursor** | Done in the production codebase / audit |
| **Requires owner login** | Console / dashboard login |
| **Requires credentials** | Secrets, signing material, API keys |
| **Requires physical device** | Hardware or emulator smoke |
| **Requires paid developer account** | Apple Developer / Google Play |
| **Requires explicit deployment approval** | Do not run until written approval |

---

## Completed by Cursor

- [x] Phases 1–16 integrated; architecture single router/shell/bootstrap/DI
- [x] Phase 15 quality gates + Phase 16 release workflows/docs
- [x] Crashlytics/Performance wrappers with web + Firebase-unavailable fallback
- [x] Remote Config release module (maintenance / force-update / flags loaded)
- [x] Optional Android release signing when `key.properties` exists
- [x] AGP transition flags (`android.newDsl=false`, `android.builtInKotlin=false`)
- [x] `moderation_queue` client writes denied
- [x] FCM deep-link route validation hardened
- [x] CI `.firebaserc` materialization from Environment **vars**
- [x] Web/Android/iOS branding + privacy string updates
- [x] Final audit docs set created
- [x] Approved disk cleanup executed
- [x] Post-cleanup validation: Android debug APK, Flutter web, Chrome launch, Firebase rules (40/40)
- [x] Rules config fixes: safe `isAdmin`, `canReadUserProfile`, RTDB `hasChildren`, firebase_tests npm registry

---

## Disk / local machine

- [x] Free **≥15 GB** and completed heavy builds / rules tests (2026-07-19)
- [ ] Optional: clear `~/.gradle/wrapper` dists (~0.5 GB) if unused — owner decision
- [ ] Keep ≥15 GB free before future release/IPA builds — **Requires owner login** (local machine)

---

## Firebase & backend

- [ ] Create isolated Firebase **development / staging / production** projects — **Requires owner login**
- [ ] Set GitHub Environment vars `FIREBASE_STAGING_PROJECT_ID`, `FIREBASE_PRODUCTION_PROJECT_ID` — **Requires credentials** + **Requires owner login**
- [ ] Configure GitHub Environments `staging` / `production` / `android-release` / `ios-release` with distinct WIF SAs — **Requires credentials**
- [ ] Generate FlutterFire options + `google-services.json` / `GoogleService-Info.plist` (never commit) — **Requires credentials**
- [ ] Publish Remote Config from `remoteconfig.template.json` — **Requires owner login**
- [ ] `firebase functions:secrets:set OPENAI_API_KEY` per env — **Requires credentials**
- [ ] Configure media-processor secrets if used — **Requires credentials**
- [ ] App Check providers: monitor → enforce (see `APP_CHECK_ROLLOUT.md`) — **Requires owner login**
- [ ] Set admin Auth custom claims for break-glass operators only — **Requires credentials**
- [ ] Staging deploy (rules/indexes/functions/remoteconfig) — **Requires explicit deployment approval**
- [ ] Production deploy from signed tag — **Requires explicit deployment approval**

---

## Android

- [ ] Replace `com.example.reemove_app` applicationId/namespace — **Requires owner login** + **Requires paid developer account** (Play)
- [ ] Create upload keystore; local `android/key.properties` — **Requires credentials**
- [ ] Store CI secrets: `ANDROID_UPLOAD_KEYSTORE_B64`, passwords, alias, `PROD_DART_DEFINES_JSON` — **Requires credentials**
- [ ] Apply Maps key via `configure_google_maps.py` (restricted) — **Requires credentials**
- [ ] Enroll Play App Signing; fill Data safety from `config/privacy/play_data_safety.yaml` — **Requires paid developer account**
- [ ] Internal / closed testing track smoke — **Requires physical device** + **Requires paid developer account**
- [ ] Staged production rollout — **Requires explicit deployment approval**

---

## iOS

- [ ] Replace `com.example.reemoveApp` bundle ID — **Requires paid developer account**
- [ ] Capabilities: Push, Sign in with Apple, Associated Domains, App Attest — **Requires owner login** (Xcode) + **Requires paid developer account**
- [ ] Distribution cert + App Store profile; fill `ExportOptions.plist` (do not commit) — **Requires credentials**
- [ ] CI secrets: `IOS_EXPORT_OPTIONS_PLIST`, `PROD_DART_DEFINES_JSON`, signing mechanism — **Requires credentials**
- [ ] APNs key uploaded to Firebase — **Requires credentials**
- [ ] TestFlight internal / external — **Requires physical device** + **Requires paid developer account**
- [ ] App Store privacy answers + submission — **Requires paid developer account** + **Requires explicit deployment approval**

---

## Maps / FCM / AI / links

- [ ] Restrict Maps API keys by package / bundle — **Requires credentials**
- [ ] FCM + APNs end-to-end on physical devices — **Requires physical device** + **Requires credentials**
- [ ] Host support / status / legal / account-deletion URLs — **Requires owner login**
- [ ] Deep links: finalize IDs then `configure_deep_links.py` + host AASA/assetlinks — **Requires owner login** + **Requires credentials** (signing hashes)

---

## Legal / store / ops

- [ ] Lawyer review of `legal_templates/` — **Requires owner login**
- [ ] Fill store metadata (`config/store_metadata/`) — **Requires owner login**
- [ ] Sign Phase 15 `RELEASE_READINESS_SCORECARD.md` — **Requires owner login**
- [ ] Backup / restore / rollback rehearsal — **Requires owner login** + **Requires explicit deployment approval** for prod drills
- [ ] Configure Crashlytics / Performance / Analytics alerts — **Requires owner login**

---

## Explicit “do not deploy yet”

Cursor will **not** deploy Firebase, upload to Play, or push TestFlight/App Store without a written message approving the target environment and artifact.
