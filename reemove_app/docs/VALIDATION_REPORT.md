# Validation report — Phase 6

Validation date: 2026-07-13

## Passed in this environment

- Repository JSON and YAML parsing.
- Relative Dart import resolution.
- Clean Architecture boundary validation preventing Firebase SDK types from leaking into domain files.
- Shell and Python syntax validation.
- Native Android/iOS deep-link configurator fixture and idempotency tests.
- Firebase Rules test-source JavaScript syntax validation.
- Cloud Functions ESLint.
- Cloud Functions strict TypeScript compilation.
- Cloud Functions seed compilation.
- Backend policy tests: **22 passed**.
  - 7 content publishing, text, and feed-ranking tests.
  - 4 onboarding age/geospatial policy tests.
  - 3 onboarding request-parser tests.
  - 4 username/display-name policy tests.
  - 4 recent-authentication-window tests.
- Dart tree-sitter grammar parse: **212 files passed** with no syntax-error or missing-token nodes.
- Feed cursor/query/index source alignment review.
- Missing-reaction document authorization review.
- Reciprocal block-index and direct-access policy review.
- Draft upload ownership, MIME, size, metadata, and processor-prefix review.
- Media job dispatch and authenticated callback ownership review.
- Source/configuration dependency and naming consistency review.
- Package-lock files are present for Functions and Rules tests.

## Phase 6 behavior represented by tests and source checks

- Publishing rejects invalid media combinations, unsafe text, excessive media, invalid story content, and malformed hashtags/mentions.
- Ranking is deterministic and clamps negative or invalid counters.
- Clients cannot directly create or update posts, stories, comments, reactions, reposts, feed entries, media assets, media jobs, or trusted counters.
- Existing and missing viewer reaction/view documents use UID-prefixed deterministic IDs.
- Public, private, processing, removed, and expired content policies are represented in Security Rules tests.
- Blocked users lose direct post/story access in either direction; reciprocal block indexes remain private.
- Public list queries remain bounded and application-side block filtering prevents blocked accounts from rendering.
- Draft uploads require owner/path-bound metadata and are readable only by the owner.
- Both supported processed-media prefixes deny client writes.
- Seed data covers image posts, carousel content, a reel, comments, reactions, following feed entries, and a story.

## Firebase Rules emulator result

`npm run test:rules` was executed. Firebase CLI began the Firestore and Storage emulator workflow, but this environment could not download:

```text
cloud-firestore-emulator-v1.21.0.jar
```

The executable emulator assertions therefore did **not** run here. The Rules source, expanded test suite, package lock, ports, indexes, and CI wiring are included. Run before staging:

```bash
npm --prefix firebase_tests ci
npm run test:rules
```

## Flutter SDK limitation

The Flutter/Dart SDK and generated native projects are unavailable in this execution environment. These required commands were not run here:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build appbundle
flutter build ipa
flutter build web
```

Tree-sitter grammar parsing is not a substitute for package resolution, analyzer type checking, widget/integration tests, accessibility testing, or native builds.

## Dependency audit

- `firebase_tests`: **0 known vulnerabilities**.
- `functions` production dependency tree: **9 moderate, 0 high, and 0 critical** advisories.
- No forced major dependency upgrade was applied solely to silence transitive advisories. Re-evaluate the Firebase Admin/Functions dependency tree during release hardening.

## Media infrastructure limitation

The external video processor is represented by a complete authenticated dispatch/callback contract, but no third-party processor endpoint or cloud account credential is committed. Video processing must be deployed and tested using `MEDIA_PROCESSING_SETUP.md` before enabling video publishing in staging or production.

## Reproduction commands

```bash
python3 scripts/validate_repository.py
python3 scripts/test_configure_deep_links.py
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
npm --prefix functions run test:unit
npm --prefix firebase_tests ci
npm run test:rules
flutter analyze
flutter test --coverage
```

Deployment remains blocked until Flutter analysis/tests, physical-device media tests, native builds, the complete emulator Rules suite, and the external media processor integration pass in staging.
