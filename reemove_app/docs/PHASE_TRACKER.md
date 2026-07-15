# Phase tracker

| Phase | Name | Status | Primary deliverable |
|---:|---|---|---|
| 1 | Project architecture | **Complete** | App foundation, design system, routing, environments, Firebase bootstrap, CI/docs |
| 2 | Database design | **Complete** | Typed schema, converters, repositories, rules tests, indexes, seeds |
| 3 | Authentication | **Complete in this package** | Email, Google, Apple, usernames, linking, verification, reset, reauthentication, session revocation, account lifecycle |
| 4 | Onboarding | **Complete in this package** | Resumable ten-step flow, private age/location, avatar, preferences, trusted completion |
| 5 | Navigation | **Complete in this package** | Six-tab adaptive shell, stateful branches, guarded deep links, native app-link setup |
| 6 | Feed | **Complete in this package** | Ranked/following feeds, publishing, media jobs, stories, reels, comments, reactions, reports, blocks |
| 7 | Profiles | **Complete in this package** | Profiles, follow graph, verification, settings |
| 8 | Messaging | **Complete in this package** | Direct/group chat and media |
| 9 | Sports hubs | **Complete in this package** | Football, gym, running and shared module contracts |
| 10 | Nearby maps | **Complete in this package** | Places, people, matches, routes, filters |
| 11 | Challenges | **Complete in this package** | Weekly/community/AI challenges and rewards |
| 12 | Marketplace | **Complete in this package** | Listings, filters, seller profiles, favorites, chat |
| 13 | Notifications | **Complete in this package** | FCM, inbox, preferences, deep links |
| 14 | AI modules | **Complete in this package** | Coach, workout, nutrition, matchmaker, challenges, content, trainer insights |
| 15 | Testing | Planned | Full automated, security, performance, accessibility hardening |
| 16 | Deployment | Planned | Store releases, CI/CD, staged rollout, operations |

## Phase 6 exit gate

Phase 6 is complete when:

- For You and Following feeds use stable bounded cursors and preserve authoritative server state.
- Posts, image carousels, reels, and stories render real media and production states.
- Drafts survive restarts and uploads expose progress and retry-safe failures.
- Callable Functions own publishing, counters, reactions, comments, views, reports, and blocks.
- Videos remain processing until a trusted external processor callback verifies output ownership.
- Firestore/Storage rules, indexes, seed data, policy tests, and media deployment documentation ship with the feature.
- Reciprocal block indexes hide both directions without making broad public queries fail.
- Repository validation, Functions lint/build, backend tests, and Dart grammar checks pass.

## File ownership rule

Every generated file is tracked by Git. Later phases modify an existing file only when integration requires it. Architectural changes require an ADR entry and migration notes.
