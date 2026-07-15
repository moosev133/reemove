# Phase 7 completion — profiles and social graph

Completion date: 2026-07-13

## Scope delivered

Phase 7 turns the Profile branch into a complete production feature rather than a static account page. It adds role-aware public profiles, server-owned follow relationships and private-account requests, profile editing, privacy controls, verification workflows, content tabs, connection management, blocked-account recovery, and trusted counter maintenance.

## User-facing capabilities

- Athlete, trainer, sports-business, and ReeMove-team profile presentation.
- Cover image, avatar, biography, website, favorite sports, primary sport, goals, and professional details.
- Verified identity display with athlete, trainer, and business categories.
- Follow, request, requested, following, and blocked relationship states.
- Followers and following lists with cursor pagination.
- Incoming follow-request review, cancellation, follower removal, and unfollow.
- Posts, reels, saved, and reposted profile tabs. Saved and reposted content remain owner-only.
- Profile editing with owner-scoped avatar and cover uploads.
- Username changes protected by uniqueness and cooldown policy.
- Privacy controls for follow approval, messages, mentions, tags, activity status, sports, goals, location, follower lists, like counts, discovery, and suggestions.
- Verification submission, secure evidence upload, cancellation, status display, rejection feedback, and resubmission.
- Blocked-profile list and unblock action.
- Adaptive profile headers and content grids for compact and large layouts.

## Trusted backend capabilities

Cloud Functions own all graph and identity mutations:

- `getPublicProfile`
- `getProfileRelationship`
- `followProfile`
- `unfollowProfile`
- `cancelFollowRequest`
- `respondToFollowRequest`
- `removeFollower`
- `listProfileConnections`
- `listBlockedProfiles`
- `unblockUser`
- `loadProfileContent`
- `updateProfile`
- `updateProfilePrivacy`
- `submitVerificationRequest`
- `cancelVerificationRequest`
- `reviewVerificationRequest`
- `syncProfileSnapshots`

Follow counters are changed transactionally with the corresponding edges. Private accounts create pending requests instead of edges. Blocking removes existing relationships in both directions. Profile changes synchronize denormalized author snapshots used by posts and stories. Verification approval updates both Firestore profile state and Firebase Auth custom claims.

## Security and privacy

- Clients cannot directly create or alter follow edges, requests, profile counters, verification state, privileged role fields, or identity fields.
- Public, followers-only, and private profile access is enforced independently.
- Non-owner profile payloads are sanitized server-side; direct public user-document reads are denied.
- Block checks apply in both directions.
- Follow requests are private and server-owned.
- Verification records are readable only by their owner and administrators.
- Verification evidence uses owner-scoped private Storage paths.
- Avatar and cover uploads validate owner, path-bound metadata, content type, and size.
- Profile update, follow, and verification operations use server rate limits and audit events.
- Saved and reposted content is never exposed on another user’s profile.

## Data and indexes

Phase 7 activates or extends:

- `users/{uid}`
- `users/{uid}/followers/{followerUid}`
- `users/{uid}/following/{targetUid}`
- `users/{uid}/blocks/{blockedUid}`
- `users/{uid}/blocked_by/{blockerUid}`
- `users/{uid}/private/profile_settings`
- `follow_requests/{requesterUid}--{targetUid}`
- `verification_requests/{uid}`
- Existing `posts`, `stories`, `content_reactions`, and `reposts` queries for profile tabs

The deterministic emulator dataset is now `2026-07-13.phase7.v1`.

## Validation completed here

- Repository structure/configuration validation passed.
- Cloud Functions ESLint passed.
- Strict TypeScript compilation passed.
- Backend policy tests: **30 passed**.
- Firestore and Storage Rules test sources passed JavaScript syntax validation.
- JSON/YAML, shell, Python, relative-import, and domain-boundary checks passed.
- Package locks are present for Functions and Rules tests.

## Environment-limited checks

Flutter/Dart SDK tooling is unavailable in this execution environment, so package resolution, formatting, analyzer checks, Flutter tests, and native builds must run on a Flutter-equipped machine. The Firebase Rules test command was attempted after installing its locked dependencies, but emulator startup did not complete before the environment timeout. These remain release-blocking checks in CI/staging.

## Exit status

Phase 7 is complete at the source, architecture, backend-policy, security-rule-source, documentation, and seed-data level. Production release remains gated by Flutter analysis/tests, native device testing, and successful executable Firebase emulator Rules tests.

Next phase: **Phase 8 — Messaging**.
