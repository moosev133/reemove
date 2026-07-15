# Validation report — Phase 4

Validation date: 2026-07-13

## Passed in this environment

- Repository JSON parsing.
- YAML parsing for `pubspec.yaml`, analysis options, and CI workflow.
- Relative Dart import resolution.
- Clean Architecture boundary check preventing Firebase types in domain files.
- Shell syntax validation.
- Python syntax validation for repository and native-configuration tools.
- Node syntax validation for Firestore and Storage Rules tests.
- Cloud Functions ESLint.
- Cloud Functions strict TypeScript compilation.
- Cloud Functions/Auth/Firestore seed compilation.
- Backend unit tests: **15 passed**.
  - 4 onboarding age/geospatial policy tests.
  - 3 onboarding request-parser tests.
  - 4 username/display-name policy tests.
  - 4 recent-authentication window tests.
- Dart tree-sitter grammar parse: **141 files passed** with no syntax-error nodes.
- Repository architecture/configuration validation passed.
- Native permission patcher fixture test passed and remained idempotent on a second run.
- Firebase Rules test dependencies installed with zero npm audit vulnerabilities.
- Deterministic completed/incomplete Auth and Firestore seed identity consistency review.
- Callable/export/repository naming consistency review.

## Security behavior represented by automated tests

- Anonymous and unauthorized profile access is rejected.
- Active public profile reads are bounded.
- Client profile creation, username reservation, and private metadata writes are rejected.
- Owners may read only their own private onboarding draft and cannot write it directly.
- Clients cannot set `onboardingCompleted` or onboarding-owned profile personalization fields.
- Server-owned counters, verification, moderation, rate-limit, audit, and deletion records remain protected.
- Avatar Storage ownership, path, content type, metadata, and size policies remain covered.
- Onboarding request version, goal catalog, coordinate range, list bounds, age policy, and geohash behavior are unit tested.

## Rules emulator execution result

`npm run test:rules` was attempted. The command timed out during Firebase Emulator startup in this execution environment before the Firestore/Storage assertions ran. Test source, configuration, JavaScript syntax, dependencies, ports, and CI wiring are complete, but this report does not claim the Rules assertions executed here.

Run the suite on a machine where Firebase emulator binaries can be downloaded and cached:

```bash
npm run test:rules
```

## Flutter limitation

The Flutter/Dart SDK and generated Android/iOS/web projects are unavailable in this environment, so these commands were not executable here:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
flutter build appbundle
flutter build ipa
flutter build web
```

Dart grammar parsing is not a replacement for Flutter analysis, package resolution, widget tests, or native builds. Those checks remain mandatory before staging.

## Dependency audit

- `firebase_tests`: zero known npm vulnerabilities.
- `functions` production dependency tree: 9 moderate, 0 high, and 0 critical advisories.
- No unsupported forced major upgrades were applied. Re-evaluate Firebase Admin/Functions versions during each release dependency review.

## Reproduction commands

```bash
python3 scripts/validate_repository.py
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions run build
npm --prefix functions run test:unit
npm --prefix firebase_tests ci
npm run test:rules
flutter analyze
flutter test --coverage
```

Deployment is blocked until the Flutter checks, native device matrix, and full emulator Rules suite pass in CI or on a properly equipped development machine.
