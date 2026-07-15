# Phase 15 completion — Testing, QA, Security, Performance

Phase 15 quality systems are integrated into the production ReeMove package without replacing Phases 1–14 product code, the single router/shell/bootstrap graph, or inventing secrets.

## What landed

- `quality/` gates, matrices, security contract, AI red-team corpus, device matrix, release signoff
- Docs for test strategy, matrices, manual QA, security/privacy, performance, accessibility, CI/CD, Phase 16 handoff
- Flutter observability wrappers (Crashlytics / Performance with web + Firebase-unavailable fallbacks)
- Stable `TestKeys` applied to shell navigation destinations
- Deep-link policy aligned to production aliases (`/p/`, `/u/`, `/c/`, `/s/`, `/ch/`, `/m/`) and hosts
- Contract / quality unit tests under `test/core/quality/`
- Integration and feature test templates kept as `.dart.template` until wired
- Functions: AI corpus regression + callable error contract (`.cjs`), load-smoke harness (`europe-west1`)
- Firestore rules tests extended for AI / server-only collections in `firebase_tests/`
- Scripts: secret scan, package validation, coverage check, pre-release gate
- CI: repository-root workflows with `working-directory: reemove_app`, secret scan, package validation; coverage report non-blocking until threshold is met
- Dependabot for pub / npm / actions

## Intentionally deferred

- Renaming `/ enabling integration_test and test_examples templates (requires live ProviderScope wiring)
- Hard CI failure on 80%/90% coverage until the suite is expanded
- Full device-matrix / accessibility / localization / human security signoff (see scorecard)
- Crashlytics/Performance native project console enablement (Phase 16 ops)

## Manual setup remaining

1. Enable Crashlytics and Performance Monitoring in Firebase console for mobile apps
2. Wire `.dart.template` integration tests to production providers when device CI is ready
3. Fill `docs/RELEASE_READINESS_SCORECARD.md` before Phase 16 launch
4. Optionally raise coverage until the hard gate can be enforced
5. Deploy rules/functions unchanged for schema; Phase 15 added tests, not rule rewrites
