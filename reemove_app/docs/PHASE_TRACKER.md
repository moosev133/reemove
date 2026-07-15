# Phase tracker

| Phase | Name | Status | Primary deliverable |
|---:|---|---|---|
| 1 | Project architecture | **Complete** | App foundation, design system, routing, environments, Firebase bootstrap, CI/docs |
| 2 | Database design | **Complete** | Typed schema, converters, repositories, rules tests, indexes, seeds |
| 3 | Authentication | **Complete in this package** | Email, Google, Apple, usernames, linking, verification, reset, reauthentication, session revocation, account lifecycle |
| 4 | Onboarding | Planned | Sports, level, location, goals, permissions, resumable completion |
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

## Phase 3 exit gate

Phase 3 is complete when:

- All authentication routes are guarded from one typed session state.
- Profile creation and username reservation are atomic and server-owned.
- Email verification and password reset flows do not leak account existence.
- Provider linking synchronizes server-owned provider metadata without creating duplicate profiles.
- Session revocation and sensitive account deletion require recent authentication.
- Privileged account mutations are rate-limited and audited by trusted backend code.
- Authentication analytics contains no identity fields and is disabled until explicitly enabled.
- Client writes cannot create profiles, private account metadata, usernames, rate-limit records, audit records, or deletion records.
- Functions pass linting, strict compilation, and unit tests.
- Firebase Rules tests are checked in and run in CI before deployment.

## File ownership rule

Every generated file is tracked by Git. Later phases modify an existing file only when integration requires it. Architectural changes require an ADR entry and migration notes.
