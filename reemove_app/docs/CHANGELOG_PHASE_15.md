# Phase 15 Changelog

## Added

- Full-app master testing strategy and feature matrix.
- Pull-request and nightly quality workflows.
- Firebase Emulator security-contract tests.
- Flutter unit, contract, widget, integration, and performance templates.
- Functions safety, error-contract, and load-smoke tests.
- Coverage, secret, package, and release-gate scripts.
- Accessibility, localization, security, privacy, reliability, and AI evaluation plans.
- Release readiness scorecard and Phase 16 handoff.

## Architectural decisions

- Testing remains layered and feature-owned rather than concentrated in one QA folder.
- Production Firebase data must never be used by automated tests.
- The Emulator Suite is the default backend for local and CI integration tests.
- App Check enforcement is tested separately from authorization rules.
- Critical release paths use stable semantic keys instead of fragile text-only selectors.
- AI outputs are evaluated for schema validity, safety, privacy, and grounded candidate IDs.
- Performance is treated as a release contract with explicit budgets and traces.
