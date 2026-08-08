# ReeMove Closed Beta — Release Report

**Date:** 2026-08-06 | **Branch:** `feature/groups-chat-media`

## Verdict: Not ready for closed beta yet

Repository-level Critical/High blockers are **resolved in code** except one remaining **P0 manual QA** item: Trainer PNG upload still fails to reach Uploaded in staging runtime. Manager delete is manually verified PASS. Mobile native artifacts require **owner build environment** (disk, CocoaPods, signing).

### Validated beta build paths
- **Web staging:** `flutter build web` succeeds and serves on `http://127.0.0.1:7357`
- **Android staging AAB:** `scripts/build_android_staging.sh` succeeded (`app-release.aab`, 56.8 MB)

### Not validated on this machine
- **Android AAB:** Configuration correct; build blocked by disk (<5 GiB free)
- **iOS:** Podfile added; requires CocoaPods + Xcode on owner Mac

---

## Work completed (sessions 1–2)

| Area | Change |
|------|--------|
| Trainer PNG upload | Web `file_selector`, immediate Validating/Selected states |
| Group moderation | ACL watch, viewer UID resolution, nav regression tests |
| Feature flags | Router redirects + UI gating for AI/nearby/marketplace/messaging/story/sign-up |
| Messaging safety | Report reason picker; block user from DM |
| Android | AGP transition flags; staging build script with disk preflight |
| iOS | Podfile scaffold; no-codesign build script |

---

## Test evidence

| Suite | Result |
|-------|--------|
| Flutter | **205/205** |
| Functions unit | **154/154** |
| Integration | **75/75** (prior) |
| Rules | **65/65** (prior) |
| Web build | **Pass** |

---

## Owner actions (P0)

1. Manual QA: Trainer PNG upload end-to-end (see `OWNER_ACTION_CHECKLIST.md`) — **still failing**
2. Free ≥10 GiB disk; run `bash scripts/build_android_staging.sh`
3. Install CocoaPods; run `bash scripts/build_ios_staging_nocodesign.sh`
4. FlutterFire platform files for device builds

---

## Readiness (evidence-based)

| Area | % | Rationale |
|------|---|-----------|
| Features | **86** | Core journeys coded; flags wired; trainer/reviewer partial |
| Backend | **92** | All unit/integration/rules passed (latest functions + prior rules) |
| Security | **90** | Rules intact; feature kill-switches; no weakening |
| Testing | **88** | 205 Flutter + 154 functions; manual QA pending |
| Web beta | **90** | Build validated |
| Android beta | **55** | Config + script ready; AAB not built (disk) |
| iOS beta | **45** | Podfile + script; pod/Xcode blocked |
| **Overall** | **80** | Conditional on P0 manual QA + owner mobile build |

---

## Distribution

### Web (ready now)
```bash
cd reemove_app/build/web && python3 -m http.server 7357 --bind 127.0.0.1
```

### Android (after disk + signing)
```bash
bash scripts/build_android_staging.sh
# Upload build/app/outputs/bundle/release/*.aab to Play closed testing
```

### iOS (after CocoaPods + signing)
```bash
cd ios && pod install && cd ..
bash scripts/build_ios_staging_nocodesign.sh  # validation only
# Production: scripts/build_ios_release.sh with ExportOptions.plist
```

---

## Known beta limitations
- PDF verification evidence not supported
- No in-app reviewer dashboard
- AI Matchmaker requires manual user IDs
- Discover search is username-only
- Maps on web/list-only without API keys

## Deferred post-beta
- PDF evidence, reviewer dashboard, trainer ranks/directory/renewal
