# Final production audit — ReeMove

**Date:** 2026-07-15  
**Commit baseline before audit fixes:** `80b7f84` (Phase 16)  
**Auditor:** Cursor final production-readiness workflow  
**Scope:** Production package only (`reemove_app/`). Source `reemove-gpt5.6-sol` not modified.

## Executive summary

Phases 1–16 are integrated with a coherent single-router, single-bootstrap architecture and shared Firebase DI. The app is **not store-ready** until owner credentials, real application IDs, Firebase projects, Maps/FCM/App Check, and device validation are completed.

**Disk blocker:** Free space at audit start was ~0.19 GB. Approved cleanup was executed; free space remained ~0.19 GB. All **heavy builds remain stopped** until ≥15 GB is free.

## Disk status

| Metric | Value |
|--------|------:|
| Free at start | ~0.19 GB |
| Threshold for heavy builds | 15 GB |
| After approved cleanup / OS reclaim | ~5.3 GB |
| Heavy builds | **Blocked** (<15 GB) |

### Safe cleanup already applied (approved)

- Project: `flutter clean`, `.dart_tool/`, `build/`, `android/.gradle`, `android/build`, `ios/Pods`, `ios/.symlinks`, `functions/lib`
- Global (approved): `~/.gradle/caches`

### Not deleted (per instruction)

- `functions/node_modules`, Flutter SDK, Android SDK, Xcode, personal media/Documents/Downloads, unrelated projects
- `~/.gradle/wrapper` (~488 MB) — not on the approved list; owner may delete wrapper dists manually if desired

### Owner disk recovery (outside Cursor)

Free ≥15 GB by emptying Trash, reviewing large Downloads/Movies, and optionally clearing Xcode DerivedData / Pub cache yourself before requesting a retry of APK / web / rules-test builds.

---

## Audit findings by area

### 1. Flutter architecture — Pass
Single `main.dart` → `bootstrap.dart` → `ReeMoveApp`. One AppShell, one GoRouter, one theme.

### 2. Routing and navigation — Pass with gaps
Shell aliases `/p|/u|/c|/s|/ch|/m` are consistent. **Native deep-link wiring not applied** (owner + script after real IDs).

### 3. Riverpod / DI — Pass
Shared Firebase providers only in `firebase_providers.dart`. No duplicate Auth/Firestore/Functions/Messaging graphs.

### 4. Firebase init and fallback — Pass
Unavailable bootstrap routes to auth-unavailable UX; release controls use safe defaults.

### 5. Firestore / Storage / RTDB / Functions / rules / indexes — Pass with fixes
Indexes present. AI collections server-gated. **Fixed:** `moderation_queue` client writes denied (admin read only). Storage still allows broader authenticated reads on some media paths (documented debt).

### 6. Authentication and account security — Pass (config pending)
Auth flows present; Google/Apple and App Check need owner console setup.

### 7. Notifications and deep links — Partial
FCM inbox/shell listeners work when Firebase ready. **Fixed:** FCM `route` validated via `DeepLinkPolicy` / `AppRoutes`. Native App Links / Associated Domains still owner.

### 8. Maps and location — Blocked (owner)
Permissions declared; Maps keys / gradle meta-data not configured.

### 9. AI security / quotas / secrets — Pass (owner secret)
OpenAI via `defineSecret`; daily quota present; no client keys. Burst/IP limits are future hardening.

### 10. Error / loading / empty — Pass (minor inconsistency)
Key screens use loading/empty/retry; mixed widgets (`AppEmptyState` vs `AppErrorView`).

### 11. Performance — Acceptable debt
Shell keeps unread listeners; messaging unread folds inbox docs; inbox capped at 50 without load-more.

### 12. Accessibility — Partial
Text scaler clamped; Semantickeys/`TestKeys` for nav; full a11y matrix (screen reader, large text, RTL) still owner QA.

### 13. Privacy and data deletion — Docs ready
Templates + privacy YAML present; hosted deletion URL and legal review are owner.

### 14. Logging / Crashlytics / Analytics / monitoring — Partial
Crash/perf wrappers with web fallback; console enablement + alerts owner.

### 15. CI/CD and environment separation — Pass with fix
Staging vs production workflows separate. **Fixed:** CI materializes `.firebaserc` from Environment **vars** (no IDs in Git).

### 16. Android release readiness — Not ready
`com.example.reemove_app`; optional signing correct. **Fixed:** AGP transition flags + lower Gradle heap; INTERNET + label. Debug APK **not retried** (disk).

### 17. iOS release readiness — Not ready
`com.example.reemoveApp`; capabilities checklist only. **Fixed:** display name + broader privacy usage strings.

### 18. Web release readiness — Basic Pass
**Fixed:** ReeMove branding in `index.html` / `manifest.json`. Firebase web options + App Check still owner.

### 19. Tests / E2E — Partial
63 Flutter + 81 Functions unit tests historically green. Integration templates still `.template`. Rules tests **not run** (disk + earlier npm network).

### 20. Store submission — Not ready
IDs, privacy answers, listings, signing, beta smoke — owner.

---

## Issues fixed in this audit (safe)

1. `android/gradle.properties` — `android.newDsl=false`, `android.builtInKotlin=false`; heap capped at 2G  
2. `firestore.rules` — `moderation_queue` writes server-only  
3. FCM route validation via `DeepLinkPolicy` / `AppRoutes`  
4. Deploy workflows — materialize `.firebaserc` from GitHub Environment vars  
5. Web + Android/iOS display branding / privacy copy / INTERNET permission  
6. Dart-define examples expanded (OAuth / reCAPTCHA / database URL placeholders)

## Remaining blockers (release)

| Blocker | Owner needed |
|---------|--------------|
| ≥15 GB free disk before rebuilds | Yes |
| Real Android/iOS application IDs | Yes |
| Firebase projects + FlutterFire files | Yes |
| Maps keys, FCM/APNs, App Check, OpenAI secret | Yes |
| Upload keystore / ExportOptions / Apple certs | Yes + paid accounts |
| Native deep links after IDs | Yes |
| Explicit deploy / store approval | Yes |
| Remote Config feature flags not yet enforced in UI | Cursor follow-up or owner |

## Validation (this run)

| Check | Status |
|-------|--------|
| Disk ≥15 GB | **Blocked** (~5.3 GB after cleanup/OS reclaim; still under threshold) |
| flutter pub get | **Passed** |
| dart format (touched files) | **Passed** |
| flutter analyze | **Passed** |
| flutter test | **Passed** (63) |
| Functions build / test:unit | **Passed** (81) |
| Rules tests | **Skipped** (disk <15 GB; firebase_tests node_modules absent) |
| flutter build web | **Skipped** (disk <15 GB) |
| Chrome launch | **Skipped** (disk <15 GB) |
| Android debug APK | **Skipped** (disk <15 GB; AGP config fixed for next attempt) |

See companion docs: `OWNER_ACTION_CHECKLIST.md`, `FIREBASE_DEPLOYMENT_PLAN.md`, `ANDROID_RELEASE_PLAN.md`, `IOS_RELEASE_PLAN.md`, `BETA_TEST_PLAN.md`, `ROLLBACK_PLAN.md`.
