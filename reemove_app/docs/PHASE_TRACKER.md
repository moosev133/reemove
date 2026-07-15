# Phase tracker

| Phase | Name | Status | Primary deliverable |
|---:|---|---|---|
| 1 | Project architecture | **Complete** | App foundation, design system, routing, environments, Firebase bootstrap, CI/docs |
| 2 | Database design | **Complete** | Typed schema, converters, repositories, rules tests, indexes, seeds |
| 3 | Authentication | **Complete in this package** | Email, Google, Apple, usernames, linking, verification, reset, reauthentication, session revocation, account lifecycle |
| 4 | Onboarding | **Complete in this package** | Resumable ten-step flow, private age/location, avatar, preferences, trusted completion |
| 5 | Navigation | Planned | Six-tab adaptive shell and guarded nested routing |
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

## Phase 4 exit gate

Phase 4 is complete when:

- Every required onboarding field has an executable, accessible user flow.
- The private draft restores the exact step and values after app restart.
- Birthday, exact location, and accessibility/notification preferences remain private.
- Public location is deliberately coarse and is removed when permission is not granted.
- Client Rules prevent direct draft writes and completion/profile-personalization bypasses.
- Selected sports, age, legal versions, avatar ownership, and account state are revalidated by trusted backend code.
- Completion updates public profile, private profile, preferences, and draft atomically and idempotently.
- Location and notification denial never block onboarding.
- Functions pass lint, strict compilation, and unit tests; Flutter and Rules suites pass before staging.

## File ownership rule

Every generated file is tracked by Git. Later phases modify an existing file only when integration requires it. Architectural changes require an ADR entry and migration notes.
