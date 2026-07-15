# Phase tracker

| Phase | Name | Status | Primary deliverable |
|---:|---|---|---|
| 1 | Project architecture | **Complete** | App foundation, design system, routing, environments, Firebase bootstrap, CI/docs |
| 2 | Database design | **Complete** | Typed schema, converters, repositories, rules tests, indexes, seeds |
| 3 | Authentication | **Complete in this package** | Email, Google, Apple, usernames, linking, verification, reset, reauthentication, session revocation, account lifecycle |
| 4 | Onboarding | **Complete in this package** | Resumable ten-step flow, private age/location, avatar, preferences, trusted completion |
| 5 | Navigation | **Complete in this package** | Six-tab adaptive shell, stateful branches, guarded deep links, native app-link setup |
| 6 | Feed | Planned | Posts, media, stories, reels, interactions |
| 7 | Profiles | Planned | Profiles, follow graph, verification, settings |
| 8 | Messaging | Planned | Direct/group chat and media |
| 9 | Sports hubs | Planned | Football, gym, running and shared module contracts |
| 10 | Nearby maps | Planned | Places, people, matches, routes, filters |
| 11 | Challenges | Planned | Weekly/community/AI challenges and rewards |
| 12 | Marketplace | Planned | Listings, filters, seller profiles, favorites, chat |
| 13 | Notifications | Planned | FCM, inbox, preferences, deep links |
| 14 | AI modules | Planned | Seven AI feature families behind a typed gateway |
| 15 | Testing | Planned | Full automated, security, performance, accessibility hardening |
| 16 | Deployment | Planned | Store releases, CI/CD, staged rollout, operations |

## Phase 5 exit gate

Phase 5 is complete when:

- Home, Discover, Sports, Create, Messages, and Profile render in the required order.
- Every destination owns an independent nested navigator and restores its previous stack.
- Compact layouts use bottom navigation and larger layouts use a navigation rail.
- Protected links preserve a validated internal target through every account gate.
- Post, profile, conversation, and sport aliases resolve into the correct branch.
- Unknown or unauthorized deep-linked content fails safely.
- Android App Links, iOS Universal Links, and the custom scheme are configured idempotently.
- Navigation helpers, badge state, repository validation, and Dart grammar checks pass.

## File ownership rule

Every generated file is tracked by Git. Later phases modify an existing file only when integration requires it. Architectural changes require an ADR entry and migration notes.
