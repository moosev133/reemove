# Validation report — Phase 5

Validation date: 2026-07-13

## Passed in this environment

- Repository JSON and YAML parsing.
- Relative Dart import resolution.
- Clean Architecture boundary validation preventing Firebase SDK types from leaking into domain files.
- Shell and Python syntax validation.
- Native Android/iOS deep-link configurator fixture test.
- Deep-link configurator idempotency on a second run.
- Firebase Rules test-source JavaScript syntax validation.
- Cloud Functions ESLint.
- Cloud Functions strict TypeScript compilation.
- Cloud Functions/Auth/Firestore seed compilation.
- Backend unit tests: **15 passed**.
  - 4 onboarding age/geospatial policy tests.
  - 3 onboarding request-parser tests.
  - 4 username/display-name policy tests.
  - 4 recent-authentication-window tests.
- Dart tree-sitter grammar parse: **168 files passed** with no syntax-error nodes.
- Navigation destination ordering and route-contract source review.
- Stateful branch navigator-key and restoration-scope review.
- Guarded internal `returnTo` sanitization review.
- Username-based profile-resolution boundary review.
- Source/configuration dependency and naming consistency review.

## Phase 5 behavior represented by tests

- The six destinations retain the specification order: Home, Discover, Sports, Create, Messages, and Profile.
- Route helpers generate canonical nested and short-link paths.
- External, malformed, and non-protected return targets are rejected.
- Navigation badge totals are bounded and display values are capped safely.
- Native link declarations can be applied repeatedly without duplicate entries.
- Public profile links resolve through the server-owned username reservation index rather than an unrestricted username query.

## Firebase Rules emulator result

`npm run test:rules` was executed. Firebase CLI started the Firestore and Storage emulator workflow, but the Firestore emulator binary could not be downloaded in this environment. The emulator assertions therefore did **not** execute here.

The Rules source, test source, package lock, ports, and CI wiring are present. Run the suite on a development or CI machine with Firebase emulator binaries available:

```bash
npm --prefix firebase_tests ci
npm run test:rules
```

Phase 5 introduces no new client-writable collection; the Rules suite remains the cumulative policy suite from Phases 2–4.

## Flutter SDK limitation

The Flutter/Dart SDK and generated Android/iOS/web projects are unavailable in this execution environment, so these commands were not run here:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build appbundle
flutter build ipa
flutter build web
```

Tree-sitter grammar parsing is not a replacement for Flutter package resolution, analyzer type checking, widget tests, integration tests, accessibility testing, or native builds. All remain mandatory before staging.

## Dependency audit

- `firebase_tests`: 0 known vulnerabilities.
- `functions` production dependency tree: 9 moderate, 0 high, and 0 critical advisories.
- No forced major dependency upgrade was applied solely to silence transitive advisories. Re-evaluate Firebase Admin and Functions dependencies during release hardening.

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

Deployment remains blocked until Flutter analysis/tests, native device builds, and the complete emulator Rules suite pass on a properly equipped machine.
