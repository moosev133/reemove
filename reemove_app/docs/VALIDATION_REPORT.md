# Validation report — Phase 3

Validation date: 2026-07-13

## Passed in this environment

- Repository JSON parsing.
- YAML parsing for `pubspec.yaml`, analysis options, and CI workflow.
- Relative Dart import resolution.
- Clean Architecture boundary check preventing Firebase types in domain files.
- Shell syntax validation.
- Node syntax validation for Firestore and Storage Rules tests.
- Cloud Functions ESLint.
- Cloud Functions strict TypeScript compilation.
- Cloud Functions/Auth seed compilation.
- Backend unit tests: **8 passed**.
  - 4 username/display-name policy tests.
  - 4 recent-authentication window tests.
- Dart tree-sitter grammar parse: **113 files passed** with no syntax-error nodes.
- Firebase Rules test dependencies installed with zero npm audit vulnerabilities.
- Deterministic Auth and Firestore seed identity/document consistency review.
- Callable/export/repository naming consistency review.

## Security behavior represented by automated tests

- Anonymous and unauthorized profile access is rejected.
- Active public profile reads are bounded.
- Client public-profile creation is rejected.
- Username reservation and private account metadata writes are rejected.
- Server-owned profile fields cannot be changed by users.
- `rate_limits`, `audit_logs`, and `account_deletions` are inaccessible to clients.
- Valid abuse reports are accepted only from their authenticated reporter.
- Storage ownership, path, content-type, and size policies remain covered.
- Username normalization/reservation policy and recent-login expiry are unit tested.

## Rules emulator execution result

`npm run test:rules` reached Firebase Emulator startup but could not download:

```text
cloud-firestore-emulator-v1.21.0.jar
```

The request to Google Storage failed in this execution environment. The test source and configuration are complete, dependencies install successfully, and JavaScript syntax passes, but the Firestore/Storage Rules assertions are not claimed as executed here.

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

They remain mandatory before staging.

## Dependency audit

- `firebase_tests`: zero known npm vulnerabilities.
- `functions`: no high or critical production advisories; eight moderate transitive advisories are reported through the Firebase Admin dependency tree.
- The Functions package uses the mutually supported pair `firebase-admin ^13.10.0` and `firebase-functions ^7.2.5`. Upgrading Admin to v14 removes some advisories but is outside the declared peer range of the current Functions SDK, so the repository does not force an unsupported combination. Re-evaluate when the Functions SDK declares Admin v14 compatibility.

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
flutter test
```

Deployment is blocked until the Flutter checks and full emulator Rules suite pass in CI or on a properly equipped development machine.
