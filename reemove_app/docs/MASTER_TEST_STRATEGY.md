# Master Test Strategy

## Objectives

The Phase 15 quality system must prove that ReeMove is functionally correct, secure by default, resilient to unreliable mobile networks, accessible, performant, privacy-aware, and safe for its target audience.

## Test layers

### Unit tests

Test pure domain logic, validators, mappers, use cases, ranking calculations, challenge progress, pagination state, notification routing, AI safety checks, and error translation. Unit tests must not require Firebase or network access.

### Widget tests

Test visual states and interaction contracts: loading, empty, success, partial data, offline, permission denied, expired content, validation errors, and retry. Use provider/repository overrides so widgets remain deterministic.

### Repository and contract tests

Verify model serialization, Firestore document mapping, callable request/response shapes, Storage metadata, notification payloads, deep links, and backward-compatible schema behavior.

### Firebase Emulator tests

Run Authentication, Firestore, Storage, and Functions against isolated local emulators. Validate authorization, ownership, privacy, blocking, admin claims, server-only collections, field validation, rate limits, idempotency, and transactional behavior.

### Integration tests

Test feature flows through the Flutter application with emulator-backed services: registration, onboarding, publishing, following, messaging, joining events, recording challenge progress, marketplace contact, notifications, and AI generation.

### Device / end-to-end tests

Run a small set of business-critical journeys on representative Android and iOS devices. Include permissions, camera/gallery, maps, push notifications, background/foreground transitions, deep links, low-memory restart, rotation where supported, and interrupted network conditions.

### Manual exploratory testing

Human testing remains required for visual polish, animation, gesture conflicts, copy quality, accessibility, cross-language layout, unusual user behavior, and subjective sports-community experience.

## Ownership

- Feature engineers own unit, widget, repository, and integration tests for their code.
- Firebase owners own rules and functions tests.
- QA owns cross-feature journeys, manual matrices, regression tracking, and signoff evidence.
- Security/privacy owners review the threat model, authorization contracts, data handling, and release exceptions.
- Product owns acceptance criteria and release priority.

## Environments

1. Local: Firebase Emulator Suite, deterministic seed data, debug App Check tokens.
2. CI: fresh emulators per job, ephemeral test accounts, no production credentials.
3. Staging: isolated Firebase project, production-like indexes/config, synthetic or consented test data only.
4. Production: smoke checks only; no destructive automated tests.

## Test data rules

- Never copy production messages, media, location history, contacts, or AI conversations into test environments.
- Use generated identities and coarse synthetic locations.
- Mark test accounts and clean them automatically.
- Store secrets only in environment-specific secret managers.
- Use deterministic clocks and IDs where behavior depends on time.

## Regression policy

Every fixed defect receives a regression test at the lowest effective layer. P0/P1 regressions require an automated test before closure unless a documented technical reason is approved.

## Flaky-test policy

A flaky test is a defect. Quarantine is temporary, must have an owner and expiration, and cannot hide failures in authentication, payments/marketplace contact, security rules, privacy, messaging, or AI safety.

## Exit criteria

Phase 15 exits only when all release gates in `quality/quality_gates.json` and `RELEASE_READINESS_SCORECARD.md` are satisfied or explicitly approved with an owner, risk statement, mitigation, and expiry date.
