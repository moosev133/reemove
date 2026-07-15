# Phase 2 database implementation

## Scope

Phase 2 converts the Phase 1 schema into an enforceable, typed Firebase data layer. It does not implement feature UI or end-user write flows that belong to later phases.

Implemented now:

- Provider-neutral domain entities and value objects.
- Firestore DTOs and mappers for the first shared data families.
- Central typed Firestore collection references using `withConverter`.
- Repository contracts and Firebase implementations.
- Composite indexes for the implemented queries.
- Firestore and Storage Security Rules with deny-by-default fallbacks.
- Emulator test suites for profile privacy, server-owned fields, public catalog reads, reports, upload ownership, media type/size limits, and processed media protection.
- Deterministic emulator seed data.
- Schema and migration version conventions.

## Layer boundary

```text
Flutter UI
    ↓
Application controllers/use cases
    ↓
Domain repository contracts + provider-neutral entities
    ↑
Firebase repository implementations
    ↑
Firestore DTOs / mappers / typed collection converters
    ↑
Cloud Firestore
```

The following Firebase types are restricted to `lib/**/data` and `lib/core/database`:

- `DocumentSnapshot`
- `QuerySnapshot`
- `Timestamp`
- `GeoPoint`
- `FieldValue`
- `FirebaseException`

Domain entities use `DateTime`, `GeoLocation`, `Money`, and `MediaAsset` instead.

## Typed collections

`ReeMoveFirestore` currently exposes typed references for:

| Firestore collection | DTO | Domain model |
|---|---|---|
| `users` | `UserProfileDto` | `UserProfile` |
| `sports` | `SportDefinitionDto` | `SportDefinition` |
| `places` | `SportPlaceDto` | `SportPlace` |
| `events` | `SportsEventDto` | `SportsEvent` |
| `challenges` | `ChallengeDto` | `Challenge` |
| `marketplace_listings` | `MarketplaceListingDto` | `MarketplaceListing` |
| `app_config` | `AppConfigurationDto` | `AppConfiguration` |
| `feature_flags` | `FeatureFlagDto` | `FeatureFlag` |

Later phases add DTOs to this registry only when the feature owns a real read/write flow.

## Repository contracts

- `UserProfileRepository`
  - Read/watch one profile.
  - Bounded batch retrieval of active public profiles.
- `SportsCatalogRepository`
  - Watch enabled sports.
  - Read one sport.
  - Watch active public places for a sport.
  - Watch upcoming published events.
- `ChallengeRepository`
  - Watch active challenges per sport.
  - Read one challenge.
- `MarketplaceCatalogRepository`
  - Watch latest active listings, optionally by sport.
  - Read one active listing.
- `AppConfigurationRepository`
  - Watch mobile app configuration.
  - Watch authenticated feature flags.

All repository methods return `Result<T>` or `Stream<Result<T>>`. Firebase and malformed-document errors are mapped into user-safe `Failure` values.

## Query limits

Every user-driven collection query must be bounded. Current limits are:

- Public profile batches: maximum 30 document IDs.
- Places: default 30, rules maximum 50.
- Events: default 30, rules maximum 50.
- Challenges: default 20, rules maximum 50.
- Marketplace listings: default 30, rules maximum 50.

Pagination cursors will be added with each feature's complete browsing UI. Unbounded arrays are prohibited for high-cardinality relationships.

## Server-owned fields

Client rules prevent direct mutation of:

- Username identity and normalized username.
- User role and verification state.
- Follower, following, and post counters.
- Moderation state.
- Catalog definitions.
- Aggregate marketplace counters.
- Challenge participant counts.
- Audit logs and migration markers.

Trusted Cloud Functions or administrative tooling own these transitions.

## Media metadata contract

Client uploads must include custom metadata:

```text
ownerId=<authenticated uid>
schemaVersion=1
```

Allowed client upload areas in Phase 2:

- User avatars.
- Original post media.
- Story media.
- Marketplace listing images.
- Verification images.
- Report evidence.

Processed post media is readable by authenticated users but writable only by trusted backend services. Messaging, group, event, and route media remain denied until their owning phases add membership/ownership rules and tests.

## Local verification

```bash
# Functions
cd functions
npm install
npm run lint
npm run build
cd ..

# Firestore + Storage rules
cd firebase_tests
npm install
cd ..
npm run test:rules

# Deterministic emulator data
npm run seed:emulator
```

The rules suite uses the official `@firebase/rules-unit-testing` API and Node's built-in test runner.
