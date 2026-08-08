# Trainer Verification System — Implementation Status

Evidence-based status derived from the current codebase (not the legacy roadmap).
There is **no separate Trainer Verification product package**. Trainer verification
uses the shared Phase 7 **profile verification** flow (`requestedType: trainer`)
plus the sports-hub trainer directory that consumes approved verification.

**Last updated:** 2026-08-06  
**Module status:** **P0 blocker remains** — picker opens, but staging upload still fails to reach **Uploaded** reliably in manual QA.

## Requirement checklist

| # | Requirement | Status | Evidence |
|---|-------------|--------|----------|
| 1 | Trainer application workflow | **Partial / manual QA failed (P0)** | Apply UI + draft/submit callables; blocked until staging upload reaches Uploaded and Submit reaches **Pending** |
| 2 | Certification and verification-document uploads | **Partial / manual QA failed (P0)** | PNG selection begins, but upload path still stalls/fails before stable Uploaded in real staging run |
| 3 | Secure reviewer/admin dashboard | **Not started** | Docs: no mobile admin UI; `reviewVerificationRequest` exists (admin claim only) |
| 4 | Approve, reject, or request additional documents | **Partial** | Approve + reject via callable; **no** request-more-docs decision |
| 5 | Trainer ranks and verification badges | **Partial** | Badge via `isVerified` + `verificationType`; **no** trainer rank/tier model |
| 6 | Categorized trainer directory | **Partial** | Per-sport hub trainers list; no global multi-facet directory |
| 7 | Search/filter by sport, specialty, location, rank, availability | **Partial** | Sport + `acceptingClients`; specialty/location/rank filters absent |
| 8 | Certification expiration and renewal | **Not started** | No expiry/renewal fields, jobs, or UI |

## Product decisions (conservative)

1. **Reuse shared verification**, not a parallel trainer-only collection — keeps
   existing athlete/business flows and Storage paths intact.
2. **Draft is server-owned** via `saveVerificationDraft` (client cannot write
   `verification_requests`).
3. **Evidence remains image-based** for this slice (PNG/JPEG). Storage rules are
   PNG/JPEG-scoped for verification paths; PDF certifications are a follow-up.
4. **Certification metadata** is stored on evidence items (`documentKind`,
   optional `issuer` / `issuedAt` / `expiresAt`) without requiring expiry
   enforcement yet (req #8).

## PNG evidence-upload bug fix (2026-08-05)

### Exact root cause

Two interacting client bugs caused Submit to show
“Upload at least one private evidence file.” after a valid PNG was picked:

1. **Draft hydration race:** `_hydrateFromRequest` cleared local evidence and
   replaced it from the draft snapshot. An empty/stale draft emission after a
   successful local upload wiped the in-memory evidence list before Submit.
2. **Silent cancel / incomplete attach UX:** Canceling the evidence-label dialog
   exited without a clear message, so a picked file could look accepted while
   never uploading or persisting metadata.
3. **Contributing factors:** profile image picker recompression risk on web;
   generic MIME (`application/octet-stream`) without magic-byte resolution;
   Submit gated only on volatile local state rather than awaiting draft
   persistence after upload.

Server rules and the evidence requirement were **not** the primary defect;
uploads that never reached persisted `_evidence` failed Submit correctly.

### Fix summary

| Area | Change |
|------|--------|
| Validation | `VerificationEvidenceValidator` — magic-byte PNG/JPEG, PDF reject, 15 MB, octet-stream via magic |
| Picker | Dedicated `PlatformVerificationEvidencePicker` (no recompression) |
| Upload UX | Selecting / Uploading(+progress) / Uploaded / Failed + Retry/Replace/Remove |
| Persistence | Auto `saveVerificationDraft` after successful upload; Submit awaits draft save |
| Hydration | Never wipe local uploads; merge by `storagePath`; watch auth so upload isn’t “signed out” |
| Server | `assertOwnedVerificationEvidence`; PNG/JPEG allowlist; path must be `verification/` |
| Storage rules | `isPngOrJpeg()` for verification create (size + owner metadata unchanged) |

### Key files

- `lib/features/profile/presentation/screens/profile_verification_screen.dart`
- `lib/features/profile/domain/services/verification_evidence_validator.dart`
- `lib/features/profile/data/services/platform_verification_evidence_picker.dart`
- `lib/features/profile/data/repositories/firebase_verification_evidence_repository.dart`
- `functions/src/profile/verificationPolicy.ts`
- `functions/src/profile/profileManagement.ts`
- `storage.rules`
- Tests: `test/features/profile/verification_evidence_validator_test.dart`,
  `profile_verification_screen_test.dart`,
  `functions/test/verificationPolicy.test.cjs`,
  `functions/test/verificationCallable.integration.cjs`,
  `firebase_tests/src/storage.rules.test.mjs`

### Automated totals (bug-fix pass)

| Suite | Result |
|-------|--------|
| Flutter analyze | No errors introduced by this slice (pre-existing unrelated infos/warnings elsewhere) |
| Flutter tests | **200/200** |
| Functions lint/build/unit | **154/154** |
| Verification + full callable integration | **75/75** |
| Firebase rules (`test:rules`) | **65/65** |

### Staging deploy (this fix)

Deployed to `reemove-staging` only:

- Callables: `saveVerificationDraft`, `submitVerificationRequest`, `cancelVerificationRequest`
- Storage rules (PNG/JPEG verification create gate)

Client rebuilt and serving at **http://127.0.0.1:7357** from `build/web`
(`main.dart.js` Last-Modified **2026-08-05 13:53:56 UTC**, contains fix markers).

Hard-refresh required before retest (Cmd+Shift+R).

## Manual QA (staging client http://127.0.0.1:7357)

**Hard refresh** so the new `main.dart.js` loads (Cmd+Shift+R / empty cache).

1. Sign in as Account A → **Profile → Settings → Profile verification → Trainer**.
2. Fill legal name + summary (≥20–30 chars as required).
3. Upload a real **PNG** evidence file; confirm status progresses to **Uploaded**
   (filename, size, document type visible). Submit stays disabled until Uploaded.
4. Leave and reopen verification → draft fields + evidence restore as Uploaded.
5. Tap **Submit verification request** → status becomes **Pending**.
6. Optional: PDF should show an immediate unsupported message; oversized image rejected.
7. Optional: Account B cannot read A’s Storage evidence / request doc (rules tests cover deny).

Do **not** mark req #1/#2 Complete until the three bullets above are confirmed manually.

### Automated staging QA

```bash
cd reemove_app
NODE_PATH=functions/node_modules node scripts/staging-qa-trainer-verification.cjs
```

Requires ADC for `reemove-staging` (`gcloud auth application-default login`).

## Existing building blocks (pre-slice)

- Callables: `submitVerificationRequest`, `cancelVerificationRequest`,
  `reviewVerificationRequest` (`functions/src/profile/profileManagement.ts`)
- Flutter: `profile_verification_screen.dart`, evidence + verification repositories
- Rules: `firestore.rules` + `storage.rules` verification matches
- Docs: `PROFILE_VERIFICATION_SETUP.md`

## Next unfinished dependency-ordered slices

1. Secure reviewer console + approve/reject UX (closes #3; extends #4)
2. Request-more-documents status + applicant re-upload (#4)
3. Directory filters / ranks / certification expiry (#5–#8)
4. PDF evidence support (deferred; not in this bug-fix milestone)
