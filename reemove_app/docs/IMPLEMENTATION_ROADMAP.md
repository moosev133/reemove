# ReeMove implementation roadmap

## Product goal

Build a production-quality, mobile-first sports social network for users aged roughly 14-50. The application must remain modular enough to add new sports without restructuring existing football, gym, or running modules.

## Delivery strategy

The specification defines **16 mandatory development phases**. Each phase has a production exit gate: architecture review, automated tests, Firebase rules tests, accessibility review, analytics coverage, and release notes.

### Phase 1 - Project architecture

- Feature-first Clean Architecture and dependency rules.
- Flutter flavors and environment configuration.
- Riverpod composition root.
- GoRouter infrastructure and deep-link policy.
- Premium light/dark design system.
- Firebase bootstrap, App Check, crash/error boundaries.
- CI, linting, tests, documentation, and phase tracking.

**Exit gate:** the app starts, renders its adaptive branded foundation, initializes Firebase safely, and passes static analysis/tests after FlutterFire configuration.

### Phase 2 - Database design

- Finalize Firestore documents, subcollections, indexes, counters, denormalization, geohashes, moderation fields, and retention rules.
- Add Storage paths and media metadata.
- Implement typed common models and converters.
- Create seed scripts, emulator data, rules unit tests, and data migration conventions.

### Phase 3 - Authentication

- Email/password registration and login.
- Google and Apple sign-in.
- Username reservation through a transaction-backed callable function.
- Email verification, password reset, account linking, reauthentication, account deletion, session revocation, and App Check enforcement.
- Abuse controls, rate limits, audit logging, and auth analytics.

### Phase 4 - Onboarding

- Birthday/age gate, terms/privacy consent, username, avatar, favorite sports, level per sport, location permission, goals, discovery preferences, accessibility preferences, and notification consent.
- Resumable onboarding state and server-side completion marker.

### Phase 5 - Main navigation

- Home, Discover, Sports, Create, Messages, and Profile.
- Adaptive bottom navigation/rail, nested navigation stacks, deep links, guarded routes, universal links, and preserved tab state.

### Phase 6 - Feed

- Feed ranking contract, pagination, pull-to-refresh, optimistic likes/saves/reposts, comments, media upload pipeline, video processing, stories, reels, reporting, blocking, content visibility, and offline cache.

### Phase 7 - Profiles

- Athlete/trainer/business profiles, follow graph, followers/following, verification display, statistics, posts/reels/saved tabs, privacy settings, profile editing, blocks, and account controls.

### Phase 8 - Messaging

- One-to-one chats, group conversations, typing indicators, read receipts, media, replies, reactions, message deletion, mute/archive, user blocking, push notifications, pagination, and abuse reporting.

### Phase 9 - Sports hubs

- Full football, gym, and running hubs.
- Shared sport-module contracts so basketball, tennis, swimming, cycling, MMA, and others can be added without core changes.
- Places, teams/groups, events, challenges, leaderboards, trainers, and pricing where relevant.

### Phase 10 - Nearby maps

- Google Maps, location permission handling, geohash queries, distance filtering, map/list synchronization, clustering, place details, routes, nearby matches, people, gyms, and courts.

### Phase 11 - Challenges

- Community and AI-generated weekly challenges, progress tracking, proof/verification policy, leaderboards, badges, rewards, anti-cheat controls, and push reminders.

### Phase 12 - Marketplace

- Listings, media, category/filter/search, seller profiles, favorites, listing chat, moderation, reporting, location radius, listing lifecycle, and safe transaction disclaimers. Payments are a separate reviewed expansion unless explicitly approved.

### Phase 13 - Notifications

- Activity inbox, FCM token lifecycle, topic strategy, preferences, quiet hours, grouped notifications, deep links, delivery audit, and Cloud Functions triggers.

### Phase 14 - AI modules

- Provider-neutral AI gateway.
- AI coach, workout generator, nutrition planner, sports matchmaker, challenge generator, content assistant, and trainer business dashboard.
- Prompt versioning, safety filters, quotas, structured outputs, evaluation datasets, human review, and cost telemetry.

### Phase 15 - Testing and hardening

- Unit, widget, golden, integration, emulator, rules, load, accessibility, localization, security, privacy, performance, and offline/resume testing.
- Crash reporting, analytics validation, performance traces, Remote Config kill switches, and incident runbooks.

### Phase 16 - Deployment

- Development/staging/production projects.
- Android and iOS signing, app links/universal links, store assets, privacy declarations, data deletion flow, CI/CD, staged rollout, monitoring dashboards, backups, and rollback procedures.

## Estimated size

- 16 phases
- Approximately 100-110 screens and modal flows
- Approximately 55 domain/data models
- Approximately 35 services and repositories
- Approximately 45 shared widgets
- Approximately 30 top-level collections or collection groups, plus scoped subcollections
- Expected production effort for a small experienced team: 8-14 months, depending on video infrastructure, AI scope, moderation, and marketplace policy


## Cumulative implementation status

- Phase 1: complete.
- Phase 2: complete.
- Phase 3: complete.
- Phase 4: complete.

Phase 4 ships the resumable ten-step onboarding flow, typed draft/domain layer, avatar pipeline, age and legal policy checks, coarse/public versus exact/private location handling, discovery/accessibility/notification preferences, trusted server completion, native permission automation, rules coverage, and complete/incomplete emulator users. Phase 5 begins with the adaptive six-destination application shell.
