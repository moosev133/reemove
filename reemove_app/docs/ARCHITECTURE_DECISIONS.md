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
