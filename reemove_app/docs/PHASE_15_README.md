# ReeMove — Phase 15: Testing, Quality Assurance, Security, and Performance

Phase 15 establishes the production quality system for the complete ReeMove Flutter + Firebase application. It is designed to be merged after Phases 1–14 and before Phase 16 deployment.

## Scope

The package covers:

1. Project architecture and shared components
2. Database and Firebase Security Rules
3. Authentication and onboarding
4. Main navigation
5. Feed, stories, reels, reactions, comments, saves, and reposts
6. Profiles, follows, privacy, blocking, and reporting
7. Messaging and groups
8. Football, gym, and running hubs
9. Nearby maps, places, events, routes, matches, and people
10. Challenges, rankings, badges, and rewards
11. Marketplace listings, favorites, seller profiles, and chat
12. Notifications and deep links
13. AI Coach, workout, nutrition, matchmaker, challenge, content, and trainer insights
14. Accessibility, localization, reliability, privacy, observability, and release readiness

## Test pyramid

```text
                 Device / end-to-end tests
             Integration and emulator tests
          Widget, repository, and contract tests
        Unit, validation, rules, and safety tests
```

Most tests should be fast unit, widget, repository, and emulator tests. A smaller set of critical user journeys runs on real or virtual devices.

## Included implementation

- Quality gates and release scorecard
- Test matrices and critical user journeys
- Flutter test support, observability wrappers, contract tests, and merge templates
- Firebase Firestore and Storage Security Rules test suites
- Firebase Emulator seed utilities
- Cloud Functions regression and callable-contract tests
- Performance and load smoke harnesses
- Secret scanning, coverage checking, package validation, and report generation
- GitHub Actions workflows for pull requests and nightly device tests
- Manual QA, security, privacy, accessibility, localization, and AI safety plans
- Phase 16 deployment handoff checklist

## Important merge note

The `.dart.template` files are deliberately templates because the package does not contain the final merged ReeMove application entry point, router, provider overrides, or all earlier feature class paths. Rename each template to `.dart` only after replacing the marked integration points with the real imports and providers from Phases 1–14.

All non-template scripts, JSON files, JavaScript test files, and standalone Dart contract tests are ready to merge. The Firebase rules tests describe the security contract the final rules must satisfy; update only path mappings when the Phase 2 schema uses different collection names.

## Default release gates

- Formatting, static analysis, and builds pass.
- All automated tests pass.
- Global line coverage is at least 80%.
- Critical domain and security code reaches at least 90% coverage.
- No unresolved P0 or P1 defects.
- No confirmed high or critical security findings.
- Firestore and Storage rules deny unauthorized access.
- Critical journeys pass on the supported device matrix.
- Accessibility and localization checks pass.
- Performance budgets pass or have an explicitly approved exception.
- AI safety regression suite passes.

## Running the package after merge

```bash
chmod +x scripts/*.sh
./scripts/pre_release_gate.sh
```

Individual layers:

```bash
./scripts/run_static_quality.sh
./scripts/run_flutter_tests.sh
./scripts/run_functions_tests.sh
./scripts/run_firebase_rules_tests.sh
```

## Phase status

Phase 15 is complete when the quality gates are implemented in the main repository, the templates are connected to the real app, the critical journeys pass, security and performance findings are resolved, and the release-readiness scorecard is signed.

Phase 16 will use these results to configure production Firebase projects, signing, CI/CD deployment, store releases, monitoring, rollout, incident response, and launch operations.
