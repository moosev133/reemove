# Full Application Test Matrix

The machine-readable matrix is in `quality/test_matrix.csv`. This document summarizes the required behavior.

## Authentication and onboarding

Test email/password, Google, Apple, verification where enabled, duplicate username, account recovery, sign-out, deleted/disabled account, minimum age policy, favorite sports, level, location permission, goals, back navigation, interrupted onboarding, and resumption.

## Navigation and app shell

Test all main tabs, authenticated and unauthenticated redirects, deep links, restored tab state, back-stack behavior, dark/light mode, safe areas, keyboard insets, and notification badges.

## Feed and social

Test pagination, refresh, optimistic reactions, duplicate taps, comments, saves, reposts, deleted content, blocked users, private users, media upload failure, video lifecycle, story expiration, report flow, empty feed, and offline cached content.

## Profiles and relationships

Test public/private profiles, follow/unfollow, blocked users, follower/following counts, profile editing, avatar upload, verification display, trainer profile details, ownership, account deletion, and hidden sensitive fields.

## Messaging

Test new conversations, existing conversations, groups, ordering, unread counts, typing/presence if implemented, media, retries, idempotency, deletion policy, block/report behavior, push routing, and unauthorized conversation access.

## Sports hubs and nearby

Test football, gym, and running hubs; place/event/team/route cards; filters; geospatial bounds; denied permission; approximate location; empty regions; stale records; joining/leaving; capacity; organizer controls; maps lifecycle; and distance units.

## Challenges

Test discovery, join/leave, eligibility, progress validation, duplicate submissions, proof media, leaderboard order, ties, badge/reward issuance, expiry, moderation, AI-generated safe challenges, and server-authoritative scoring.

## Marketplace

Test create/edit/delete listing, image limits, category/filter/search, favorites, seller ownership, availability, sold state, reporting, blocked-user interaction, chat handoff, invalid price, stale listing, and server-side validation.

## Notifications

Test each notification type, unread counts, mark-one/all-read, duplicate delivery, deleted target, foreground/background/terminated behavior, permission denied, token refresh, multi-device routing, deep-link authorization, and localization.

## AI modules

Test valid/invalid inputs, authentication, App Check, quotas, schemas, moderation, timeout, refusal, safe fallback, age-aware workout/nutrition behavior, candidate ID grounding, private/blocked candidate exclusion, audit storage, and no client access to secrets or server-only logs.

## Cross-cutting

Test accessibility, localization, RTL, offline/reconnect, slow network, concurrent devices, clock/timezone changes, storage pressure, app upgrade, backward-compatible documents, permissions, privacy export/delete, logging redaction, crash recovery, and performance budgets.
