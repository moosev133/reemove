# Architecture decisions

## ADR-001: Flutter with feature-first Clean Architecture

Flutter is the required preferred stack. Feature-first slices keep large teams from creating one global `models`, `services`, or `screens` directory and support adding sports modules independently.

## ADR-002: Riverpod for state and dependency injection

Riverpod provides testable dependency overrides, async state handling, and composition without `BuildContext`. Providers live beside the feature logic they expose. Business logic remains in controllers/use cases, not widgets.

## ADR-003: GoRouter for declarative navigation

GoRouter supports deep links, guarded routes, nested navigation stacks, and adaptive navigation. Route paths and names are centralized.

## ADR-004: Firebase is an implementation detail

Firebase SDK types remain in the data layer. Domain entities and repository interfaces stay provider-neutral so selected services can later migrate to dedicated backends without rewriting UI and business rules.

## ADR-005: Deny by default

Firestore and Storage end with catch-all deny rules. A new feature is incomplete until its rules and emulator tests are added. App Check complements, but does not replace, authorization rules.

## ADR-006: Server-owned usernames, counters, and privileged transitions

Username reservations, verification state, moderation state, aggregate counters, rewards, leaderboard results, and AI quotas are written only by trusted Cloud Functions or administrative services.

## ADR-007: No unbounded arrays

High-cardinality relationships use subcollections. This applies to followers, likes, saves, participants, conversation members, messages, device tokens, and notification lists.

## ADR-008: Provider-neutral AI boundary

All AI modules call a typed `AiGateway`. Prompts, model providers, quotas, safety checks, structured schemas, and evaluation versions are server-owned.

## ADR-009: Accessibility and RTL are foundation concerns

All layout primitives must support large text, screen readers, RTL, sufficient contrast, and minimum touch targets. Arabic, Hebrew, and English localization can be added without rebuilding layouts.

## ADR-010: Environments are isolated

Development, staging, and production use separate Firebase projects, App Check settings, API keys, analytics streams, and signing configurations.

## ADR-011: Manual immutable DTOs before code generation

Phase 2 uses explicit immutable DTOs and mappers rather than requiring generated source files. This keeps the checked-in project immediately inspectable and avoids build-runner output becoming a hidden prerequisite. Code generation may be introduced later if model volume justifies it, but the domain/data boundary and converter contracts remain unchanged.

## ADR-012: Typed Firestore registry

All implemented top-level collections are created through `ReeMoveFirestore` with `withConverter`. Repositories receive typed references through Riverpod and presentation code never constructs collection paths.

## ADR-013: Rules and feature code ship together

A data feature is incomplete until its document shape, query index, Security Rules, and emulator tests are committed together. The final catch-all deny remains permanent.

## ADR-014: Node built-in runner for rules tests

Security Rules tests use Node 22's built-in test runner plus the official Firebase rules-testing library. This minimizes tooling while preserving authenticated/unauthenticated emulator contexts and rules-disabled fixture setup.

## ADR-015: Atomic server-owned account provisioning

Firebase Authentication identity creation and ReeMove profile creation are separate systems. A callable Function performs username reservation, public profile creation, private account metadata, and legal-consent recording in one Firestore transaction. This eliminates username races and prevents clients from setting privileged profile fields.

## ADR-016: One typed authentication routing state

GoRouter redirects are derived from `AuthRoutingState`, which combines Firebase identity, public profile state, email verification, onboarding status, and moderation state. Screens do not independently decide whether a user is authenticated. This prevents route contradictions and makes future deep-link guards testable.

## ADR-017: Recent authentication for destructive account actions

Account deletion is allowed only when the ID token's `auth_time` is within ten minutes. The UI exposes password, Google, and Apple reauthentication based on linked providers. The server rechecks recency rather than trusting client state.

## ADR-018: Federated provider SDKs are hidden behind the repository boundary

Native Google identity acquisition uses `GoogleIdentityService`; Apple uses Firebase's provider credential flow. Web uses Firebase provider popups. Presentation knows only `AuthRepository`, preserving platform flexibility and allowing future account-linking expansion.

## ADR-019: Emulator seed data must include matching Auth and Firestore identities

Authentication tests and local development require the same UID in Auth Emulator, username reservation, public profile, and private records. Emulator-only scripts refuse to run without emulator host variables and a `demo-` project ID.


## ADR-020: Account security is enforced on both client and server

The client reauthenticates through a linked provider for good UX, while destructive callable Functions independently validate the ID token `auth_time`. Refresh-token revocation and account deletion are server-owned. Client state can never bypass recent-login enforcement.

## ADR-021: Authentication abuse controls and audit trails are server-only

Transaction-backed rate limits live in `rate_limits`; privileged identity mutations write best-effort immutable records to `audit_logs`. Both collections are denied to clients. An audit outage must be observable but must not roll back a completed security mutation.

## ADR-022: Authentication analytics is privacy-minimized and opt-in

Authentication analytics emits only event/action and provider categories. It is disabled by default and in emulator mode. Email, username, display name, UID, raw credentials, and tokens are prohibited parameters. Product/legal configuration must explicitly enable collection for a release environment.

## ADR-023: Onboarding progress is private and server-persisted

The complete draft is stored at `users/{uid}/private/onboarding` after each navigation action. A single document is appropriate because the bounded draft is one transactional aggregate, while Firestore Rules deny client writes so validation and versioning remain centralized in callable Functions.

## ADR-024: Onboarding completion is a trusted atomic transition

Clients cannot set `onboardingCompleted`, sports, levels, goals, discovery radius, or location directly. `completeOnboarding` revalidates app configuration, consent versions, active sports, avatar ownership, age, permissions, and account state, then atomically writes public profile, private profile, preferences, and draft status. This prevents modified clients from bypassing required steps.

## ADR-025: Exact and public location use different precision and storage

Exact coordinates are stored only under the owner-readable private preferences document with a precision-9 geohash. Public profiles receive coordinates rounded to two decimal places and a precision-6 geohash. Non-granted permission removes stale public location. Nearby queries must still apply exact distance filtering and visibility policy in later phases.

## ADR-026: Permission requests are contextual and optional

Location and notification APIs are invoked only from explicit controls on their dedicated steps. Denied, permanently denied, unavailable, and emulator states are modeled rather than treated as exceptions. Users may finish onboarding without either permission; settings recovery actions are offered where supported.

## ADR-027: Native permission configuration is generated idempotently

Native project folders are intentionally not committed before the owner configures FlutterFire. `configure_native_permissions.py` patches generated Android/iOS files after `flutter create`, including when-in-use-only iOS location settings, without duplicating declarations on repeated bootstrap runs.

## ADR-028: Separate navigator per primary destination

The six primary destinations use `StatefulShellRoute.indexedStack`. Each branch has a stable navigator key and restoration scope, preserving child routes and scroll state when users switch tabs. A shared stack was rejected because it loses destination context and makes back behavior unpredictable.

## ADR-029: Protected deep links use validated internal return targets

When an account gate interrupts a protected link, the requested relative route is carried in `returnTo`. The router accepts only internal authenticated paths with no scheme or host. This preserves user intent without creating an open-redirect surface.

## ADR-030: Public profile links resolve through username reservations

`usernames/{normalizedUsername}` remains the unique, transaction-owned index from username to UID. Public profile navigation resolves that direct document before loading the user profile, avoiding scans and keeping rename/deletion behavior centralized.

## ADR-031: Native link configuration is generated after Flutter bootstrap

Android and iOS folders are still generated locally. `configure_deep_links.py` applies verified HTTPS links, the custom scheme, associated-domain entitlements, and Flutter metadata idempotently after generation. Domain-verification files remain explicit deployment artifacts because signing identities are environment-owned secrets/configuration.
