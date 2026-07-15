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
