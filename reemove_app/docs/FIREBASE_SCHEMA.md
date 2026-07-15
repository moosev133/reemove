# Firebase data architecture

## Principles

- No unbounded arrays for followers, likes, members, participants, messages, or tokens.
- Use subcollections and collection-group queries for high-cardinality relationships.
- Store denormalized display snapshots where feed/message performance requires it, while preserving authoritative IDs.
- Maintain counters with trusted Cloud Functions or transactions.
- Store location as `GeoPoint`, `geohash`, and normalized searchable fields.
- Use server timestamps for ordering and audit fields.
- Soft-delete user content before retention cleanup when moderation or recovery is needed.
- Every user-generated object carries visibility, moderation state, owner ID, created/updated timestamps, and schema version.

## Top-level collections

1. `users` - public/semi-public profile and discovery fields
2. `usernames` - normalized username reservations; writes only through trusted backend
3. `sports` - sport definitions and module configuration
4. `posts` - photo/video/activity posts, including reel-type posts
5. `stories` - expiring stories
6. `conversations` - direct and group conversation metadata
7. `groups` - social/sports community groups
8. `places` - courts, gyms, tracks, facilities, and other sport places
9. `teams` - sport teams and squads
10. `events` - matches, meetups, sessions, classes, and competitions
11. `routes` - curated or user-created running routes
12. `activities` - recorded sport/activity sessions
13. `challenges` - community and AI-generated challenges
14. `leaderboards` - materialized leaderboard windows and metadata
15. `badges` - badge definitions
16. `rewards` - reward definitions and claim rules
17. `trainer_profiles` - trainer-specific professional data
18. `trainer_services` - bookable/offered trainer services and pricing metadata
19. `marketplace_listings` - equipment listings
20. `reports` - user-generated abuse/safety reports
21. `verification_requests` - verified athlete/trainer/business review workflow
22. `moderation_queue` - trusted moderation work items
23. `ai_requests` - audited AI task requests and statuses
24. `ai_artifacts` - generated plans, challenges, and structured outputs
25. `feed_entries` - optional fan-out/materialized feed rows
26. `search_documents` - normalized documents for external/full-text search synchronization
27. `app_config` - Remote Config-like server-owned product configuration
28. `feature_flags` - server-controlled rollout and kill-switch state
29. `audit_logs` - privileged security/business audit events
30. `data_migrations` - migration locks, versions, and status
31. `account_deletions` - server-only account cleanup workflow and audit status
32. `rate_limits` - server-only transactional abuse-control windows

## Scoped subcollections

### Under `users/{uid}`

- `private/profile` - email/provider/account-status metadata, owner-readable and server-writable
- `private/consents` - versioned terms/privacy/minimum-age confirmations, owner-readable and server-writable
- `followers/{followerUid}`
- `following/{followedUid}`
- `blocked/{blockedUid}`
- `saved_posts/{postId}`
- `saved_listings/{listingId}`
- `notifications/{notificationId}`
- `device_tokens/{tokenId}`
- `badges/{badgeId}`
- `challenge_progress/{challengeId}`
- `preferences/{documentId}`

### Under `posts/{postId}`

- `comments/{commentId}`
- `likes/{uid}`
- `saves/{uid}`
- `reposts/{uid}`
- `views/{shardId}` or analytics aggregation documents

### Under `stories/{storyId}`

- `views/{uid}`
- `reactions/{uid}`

### Under `conversations/{conversationId}`

- `members/{uid}`
- `messages/{messageId}`
- `typing/{uid}`

### Under `groups/{groupId}`

- `members/{uid}`
- `join_requests/{uid}`
- `posts/{postId}` references when a dedicated group feed is required

### Under `teams/{teamId}`

- `members/{uid}`
- `join_requests/{uid}`
- `roles/{roleId}`

### Under `events/{eventId}`

- `attendees/{uid}`
- `waitlist/{uid}`
- `check_ins/{uid}`

### Under `challenges/{challengeId}`

- `participants/{uid}`
- `submissions/{submissionId}`
- `leaderboard/{uid}`

### Under `marketplace_listings/{listingId}`

- `favorites/{uid}` only when listing-centric moderation/metrics require it; user-centric favorites remain authoritative for UI
- `status_history/{entryId}`

## Important document fields

### `users/{uid}`

`uid`, `username`, `usernameNormalized`, `displayName`, `bio`, `avatarUrl`, `role`, `isVerified`, `verificationType`, `favoriteSportIds`, `sportLevels`, `goals`, optional coarse `location`, `geohash`, `locality`, `administrativeArea`, `countryCode`, `discoveryRadiusKm`, `visibility`, `followersCount`, `followingCount`, `postsCount`, `onboardingCompleted`, `onboardingVersion`, `createdAt`, `updatedAt`, `schemaVersion`, `moderationState`. Birthday and exact coordinates are never public.

### `posts/{postId}`

`authorId`, `authorSnapshot`, `type`, `caption`, `media`, `sportId`, `activityId`, `placeId`, `taggedUserIds`, `visibility`, `commentsEnabled`, `likeCount`, `commentCount`, `saveCount`, `repostCount`, `viewCount`, `createdAt`, `updatedAt`, `publishedAt`, `moderationState`, `schemaVersion`.

### `events/{eventId}`

`ownerId`, `sportId`, `type`, `title`, `description`, `startAt`, `endAt`, `timezone`, `location`, `geohash`, `placeId`, `capacity`, `attendeeCount`, `price`, `currency`, `skillRange`, `visibility`, `status`, `createdAt`, `updatedAt`.

### `marketplace_listings/{listingId}`

`sellerId`, `title`, `description`, `categoryId`, `sportId`, `condition`, `price`, `currency`, `media`, `location`, `geohash`, `deliveryOptions`, `status`, `favoriteCount`, `viewCount`, `createdAt`, `updatedAt`, `moderationState`.

## Authentication-owned documents

### `usernames/{usernameNormalized}`

`uid`, `usernameNormalized`, `reservedAt`, `updatedAt`, `schemaVersion`. Exact reads are public for availability checks. Listing and all client writes are denied.

### `users/{uid}/private/profile`

`uid`, `email`, `emailNormalized`, `providerIds`, `accountStatus`, `lastSignInAt`, `sessionsRevokedAt`, `createdAt`, `updatedAt`, `schemaVersion`. Readable only by the owner; writable only by trusted backend code.

### `users/{uid}/private/consents`

`uid`, `termsVersion`, `privacyVersion`, `termsAcceptedAt`, `privacyAcceptedAt`, `minimumAgeConfirmedAt`, `createdAt`, `updatedAt`, `schemaVersion`. Readable only by the owner; writable only by trusted backend code.


### `users/{uid}/private/onboarding`

`uid`, `version`, `currentStep`, private `dateOfBirth`, `avatarUrl`, `avatarStoragePath`, selected sports, sport levels, goals, optional exact draft location, permission states, discovery/accessibility/notification preferences, `status`, `completedAt`, `createdAt`, `updatedAt`, `schemaVersion`. Clients may read only their own document; all writes use trusted callable Functions.

### `users/{uid}/private/preferences`

`uid`, `discovery`, `accessibility`, `notifications`, `locationPermission`, optional `exactLocation` (`GeoPoint`, precision-9 geohash, normalized area fields), `updatedAt`, `schemaVersion`. The public profile receives only a rounded area-level position and precision-6 geohash.

### `account_deletions/{uid}`

`uid`, `username`, `status`, `requestedAt`, `lastRetryAt`, `completedAt`, `error`, `updatedAt`, `schemaVersion`. Entirely server-only and used to make deletion progress auditable and retryable.

### `rate_limits/{uid}_{action}`

`uid`, `action`, `count`, `windowStartedAt`, `expiresAt`, `updatedAt`, `schemaVersion`. Entirely server-only. `expiresAt` is intended for a Firestore TTL policy; transaction logic remains authoritative even before cleanup occurs.

### `audit_logs/{auditId}`

`actorId`, `action`, `targetType`, `targetId`, minimized `metadata`, `createdAt`, `serverCreatedAt`, `schemaVersion`. Entirely server-only and written by trusted Functions for privileged authentication mutations.

## Storage layout

```text
users/{uid}/avatar/{assetId}.jpg
posts/{uid}/{postId}/original/{assetId}
posts/{uid}/{postId}/processed/{assetId}
stories/{uid}/{storyId}/{assetId}
messages/{conversationId}/{messageId}/{assetId}
groups/{groupId}/{assetId}
events/{eventId}/{assetId}
routes/{routeId}/{assetId}
marketplace/{uid}/{listingId}/{assetId}
verification/{uid}/{requestId}/{assetId}
reports/{reporterUid}/{reportId}/{assetId}
```

## Query and indexing strategy

- Feed: `visibility + publishedAt desc`, plus author/sport filters.
- Discover: `moderationState + publishedAt desc`, later augmented by external ranking/search.
- Nearby: geohash range query followed by exact client/server distance filtering.
- Events: `sportId + status + startAt`, plus geohash ranges.
- Marketplace: `status + sportId/categoryId + createdAt`, price filters through dedicated indexes.
- Messages: subcollection ordered by `sentAt desc`.
- Notifications: user subcollection ordered by `createdAt desc`, filtered by `readAt` when needed.

The checked-in rules remain deny-by-default. Each later phase must extend rules and add emulator tests together.


## Cumulative implementation status

Typed converters and repositories are implemented for `users`, `sports`, `places`, `events`, `challenges`, `marketplace_listings`, `app_config`, and `feature_flags`. Phase 3 additionally implements server-owned `usernames`, user-private `profile` and `consents` documents, `account_deletions`, authentication `audit_logs`, and transactional `rate_limits`. Phase 4 implements user-private `onboarding` and `preferences`, trusted personalization writes, and the coarse-public/exact-private location split. Phase 5 reuses the server-owned `usernames` index for direct public-profile link resolution. Phase 6 implements posts, comments, stories, feed entries, private reactions/views, reposts, media assets/jobs, and reciprocal block indexes. Other cataloged collections remain intentionally denied until their feature phase adds complete code, rules, indexes, and tests.

Current schema version: `1`.

Current deterministic seed dataset: `2026-07-13.phase6.v1`.

See `DATABASE_IMPLEMENTATION.md`, `AUTHENTICATION_IMPLEMENTATION.md`, `ONBOARDING_IMPLEMENTATION.md`, `FEED_IMPLEMENTATION.md`, `DATA_MIGRATIONS.md`, and the phase completion reports for executable details.

## Phase 6 social-content collections

### `posts/{postId}`

`authorId`, trusted `authorSnapshot`, `kind` (`post`/`reel`), `caption`, trusted `media[]`, normalized `hashtags[]`, `mentions[]`, optional `sportId` and `locationLabel`, `visibility`, `moderationState`, `status` (`processing`/`published`), `allowComments`, server-owned engagement counters, `rankingScore`, fan-out completion fields, timestamps, and `schemaVersion`.

### `posts/{postId}/comments/{commentId}`

`postId`, `authorId`, trusted `authorSnapshot`, normalized `text`, optional `parentCommentId`, `likeCount`, `replyCount`, `isDeleted`, `moderationState`, timestamps, and `schemaVersion`.

### `stories/{storyId}`

`authorId`, trusted `authorSnapshot`, trusted `media`, optional caption/sport, `visibility`, `moderationState`, server-owned `viewCount`, `createdAt`, `updatedAt`, `expiresAt`, and `schemaVersion`.

### `feed_entries/{recipientId}--{postId}`

`recipientId`, `postId`, `authorId`, source, ranking score, publication timestamp, creation timestamp, and schema version. Client writes are denied.

### Private interaction documents

- `content_reactions/{uid}--{postId}`: liked/saved/reposted state.
- `comment_reactions/{uid}--{commentId}`: comment-like state.
- `story_views/{uid}--{storyId}`: unique story view.
- `post_views/{uid}--{postId}`: unique post view, server-only.
- `reposts/{uid}--{postId}`: persistent server-owned repost record.

### Media processing

- `media_assets/{assetId}`: owner, draft, current trusted Storage object, kind, processing state, download/thumbnail metadata, linked content path, and timestamps.
- `media_jobs/{assetId}`: input path, owner, linked content path, queue state, attempts, dispatch/completion metadata, and errors.

### User safety subcollections

- `users/{uid}/blocks/{targetUid}`: accounts this user blocked.
- `users/{uid}/blocked_by/{blockerUid}`: reciprocal private visibility index.

Both indexes are readable only by their owning user and writable only by trusted backend code.

## Phase 6 Storage layout

```text
content/{uid}/{draftId}/{assetId}/{filename}      # owner-only draft read/write
processed/{uid}/{assetId}/{filename}              # authenticated read, server-only write
processed_content/{uid}/{assetId}/{filename}      # supported legacy processor prefix
```

Draft objects bind `ownerId`, `draftId`, `assetId`, media kind, MIME type, size, and schema version in Storage metadata. The publishing Function independently re-reads that metadata before creating content.
