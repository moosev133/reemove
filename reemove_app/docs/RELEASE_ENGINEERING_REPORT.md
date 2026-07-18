# Release engineering report — ReeMove

**Date:** 2026-07-19  
**Baseline commit:** `73728c5` (production validation)  
**Scope:** `reemove_app/` only (source `reemove-gpt5.6-sol` untouched)  
**Role:** Principal release / Flutter–Firebase DevOps pass

## Verdict

| Channel | Recommendation |
|---------|----------------|
| Closed Beta (internal / TestFlight internal / Play internal) | **Ready after owner config** (Firebase files, IDs, Maps keys, signing) |
| Open Beta | **Not yet** — needs staging deploy, App Check monitor→enforce, device smoke, privacy URLs |
| Production (public stores) | **Not yet** — all Open Beta gates + store listings, legal, staged rollout |

Implementation is complete. Remaining work is **owner credentials, console configuration, and store process** — not product features.

---

## Scores (release engineering)

| Score | Value | Notes |
|-------|------:|-------|
| **Production Readiness** | **72 / 100** | Code + local validation strong; store identity and Firebase wiring missing |
| **Security** | **86 / 100** | Rules/tests green; App Check wired safely; secrets via `defineSecret`; storage read scope debt remains |
| **Performance** | **78 / 100** | Acceptable; inbox pagination / shell listeners are known debt |
| **Code Quality** | **88 / 100** | Analyze clean; single router/DI; no TODO/FIXME in `lib/` |
| **Technical Debt** | **74 / 100** | Placeholder IDs, RC flags not UI-enforced, broad authenticated Storage reads on some paths |

---

## What was verified this pass

| Area | Result |
|------|--------|
| Flutter analyze / unit tests / Functions unit / Rules (40) | Previously PASS; secret scan PASS |
| Firestore indexes | 57 composites present; aligned with major query collections |
| Firestore / RTDB / Storage rules | Present; profile visibility + safe `isAdmin`; RTDB `hasChildren`; Storage owner uploads OK |
| Cloud Functions secrets | `OPENAI_API_KEY`, `MEDIA_PROCESSOR_SECRET` via `defineSecret` — not hardcoded |
| Env / dart-defines | Documented in examples; no invented values |
| Android | Placeholder `com.example.reemove_app`; optional signing; Maps placeholder; App Links filters; conditional Google Services plugin |
| iOS | Placeholder `com.example.reemoveApp`; Maps soft-init; Associated Domains entitlements; deep-link scheme |
| App Check | Debug providers only in debug; Play Integrity / App Attest in release; no release bypass |
| Google Maps | Scaffolding applied (no keys invented) |
| Deep links | Scaffolding for `links.reemove.app` + `reemove://open` |
| Notifications / Auth / Storage uploads | Code paths wired; need Firebase + device config |
| CI/CD | Root workflows for deploy/release; package `ci.yml` for PR quality |
| Duplicates | Single GoRouter; single Firebase provider module |
| Secrets in git | None committed (`scan_secrets.py` PASS) |

---

## Safe improvements applied this pass

| Change | Justification |
|--------|----------------|
| Fixed `configure_google_maps.py` for FlutterImplicitEngine + Python 3.7 `ET.indent` | Release scripts must run on current iOS template |
| Soft Maps key activation (no `fatalError`) | Closed beta must launch without Maps key; Nearby list mode remains |
| Fixed `configure_deep_links.py` entitlements for any Runner bundle ID | Previous matcher only accepted `com.reemove.reemove` |
| Applied Maps + deep-link native scaffolding | Unblocks owner key/host steps without inventing secrets |
| Conditional `com.google.gms.google-services` when `google-services.json` exists | Prevents build break before FlutterFire; auto-enables after |
| Updated README + this report + owner checklist | Remove stale Phase 1–6 claims; accurate release status |
| Removed local emulator debug logs | Workspace hygiene (already gitignored) |

---

## Remaining blockers (must clear before public production)

1. Replace Android/iOS application IDs (`com.example.*`)
2. Create Firebase projects; run FlutterFire; keep generated files **out of git** (or private secure store)
3. Restricted Maps API keys in `android/local.properties` / `ios/Flutter/Maps.xcconfig`
4. Upload keystore + Apple distribution certs / profiles
5. Host `assetlinks.json` + `apple-app-site-association` for the verified host
6. Enable iOS Push + App Attest capabilities; upload APNs key to Firebase
7. App Check monitor → enforce on staging then production
8. Explicit written approval before any staging/production deploy or store upload

---

## Remaining owner actions

See `docs/OWNER_ACTION_CHECKLIST.md` (updated). Highest priority for Closed Beta:

1. Firebase staging project + FlutterFire files  
2. Real (or beta) application IDs  
3. Maps keys (or accept list-only Nearby)  
4. Android upload keystore / iOS TestFlight signing  
5. FCM + APNs smoke on one physical device each  

---

## Risk assessment

| Risk | Level | Mitigation |
|------|-------|------------|
| Shipping with `com.example` IDs | Critical | Blocked by checklist; CI should refuse store upload |
| Firebase unavailable → auth wall | High until FlutterFire | Expected; bootstrap already degrades safely |
| Maps blank without keys | Medium | Soft init + list fallback |
| Storage authenticated reads too broad | Medium | Documented; harden in follow-up security sprint |
| Deep links fail verification | Medium | Host AASA/assetlinks after final IDs + SHA-256 |
| Accidental prod deploy | Low | Workflows require environment approval + signed tags |

---

## Final recommendation

**Proceed to Closed Beta preparation** as soon as owner completes Firebase + IDs + signing for a staging/internal channel.

**Do not** open public beta or production store release until Open Beta gates above are green and Phase 15 scorecard is signed.
