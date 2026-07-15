# CI/CD and Release Pipeline

## Trust boundaries

- Pull requests receive no production credentials.
- Staging deployment requires a protected branch and staging environment.
- Production deployment requires a signed version tag, passing artifacts, and a human approval in the GitHub `production` environment.
- Build and deploy jobs use least-privilege identities.
- Long-lived service-account JSON is avoided for Firebase deployment; use Google Cloud Workload Identity Federation.

## Workflow sequence

1. `ci.yml`: format, analyze, tests, Functions build/tests, rules tests, secret scan, package checks.
2. `deploy-staging.yml`: deploy approved rules/indexes/Functions to staging and run smoke tests.
3. `release-android.yml`: build signed AAB, retain symbols/checksums, upload artifact for Play Console/internal testing.
4. `release-ios.yml`: build signed IPA on macOS, retain archive/dSYM/checksums, optionally upload after approval.
5. `deploy-firebase-production.yml`: deploy backend configuration from the release tag after protected approval.
6. `post-release-verify.yml`: run production-safe health checks and capture evidence.

## Reproducibility

- Pin Flutter through `config/toolchain.yaml` and upgrade intentionally.
- Commit `pubspec.lock` and Functions lockfile.
- Record `flutter doctor -v`, Java, Gradle, CocoaPods, Xcode, and Node versions in release evidence.
- Keep build outputs immutable and checksum them before store upload.
- Store obfuscation symbols and dSYMs using release/version/build identifiers.

## Action security

Only organization-approved actions may execute. Pin third-party actions to reviewed commit SHAs. The templates use official GitHub actions and Google's official authentication action; the organization should still pin them to approved SHAs before production use.
