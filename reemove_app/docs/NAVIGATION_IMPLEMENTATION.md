# Phase 5 navigation implementation

## Scope

Phase 5 replaces the temporary authenticated handoff with ReeMove's permanent six-destination application shell:

1. Home
2. Discover
3. Sports
4. Create
5. Messages
6. Profile

The implementation uses `StatefulShellRoute.indexedStack` so every destination owns a separate nested `Navigator`. Switching tabs preserves the active child route, scroll state, and in-progress destination context instead of rebuilding a single shared stack.

## Adaptive shell

`AppShell` selects navigation chrome from the available width:

- Compact: Material 3 `NavigationBar`
- Medium: icon-and-label `NavigationRail`
- Expanded: extended `NavigationRail` with the ReeMove wordmark and theme action

The route content remains identical across widths. Layout changes do not replace controllers, repositories, or route identity.

## Branch contracts

| Branch | Root | Phase 5 nested routes |
|---|---|---|
| Home | `/home` | `/home/activity`, `/home/post/:postId` |
| Discover | `/discover` | `/discover/search`, `/discover/category/:category` |
| Sports | `/sports` | `/sports/:sportId` |
| Create | `/create` | `/create/:creationType` |
| Messages | `/messages` | `/messages/:conversationId` |
| Profile | `/profile` | `/profile/user/:username` |

The nested destinations are stable contracts. Later feature phases replace or extend their content without changing external URLs.

## Guarded return-to flow

Protected links are not discarded when authentication or onboarding is incomplete.

1. The router stores the requested protected path in a validated `returnTo` query parameter.
2. Sign-in, sign-up, password recovery, username setup, email verification, and onboarding preserve that parameter when navigating between steps.
3. After `AuthRoutingState` becomes ready, the router validates that `returnTo` is an internal protected route and sends the user there.
4. External schemes, hosts, and public/auth routes are rejected as return targets.

This prevents open redirects and makes links deterministic across account states.

## Link aliases

Short external aliases redirect into the correct branch:

- `/p/:postId` -> `/home/post/:postId`
- `/u/:username` -> `/profile/user/:username`
- `/c/:conversationId` -> `/messages/:conversationId`
- `/s/:sportId` -> `/sports/:sportId`

Custom-scheme equivalents use `reemove://open/...`. Verified HTTPS links use the configured application-link host.

## Profile resolution

Public profile links resolve through the server-owned `usernames/{normalizedUsername}` reservation before loading `users/{uid}`. This avoids a collection scan and preserves the transaction-backed username source of truth. Existing Firestore authorization still decides whether the resolved profile can be read.

## Badges

`AppNavigationBadges` and `AppNavigationBadgeController` provide a typed, bounded state adapter for Home activity and Messages counts. Phase 8 and Phase 13 connect these values to conversation and notification repositories without changing shell widgets.

## Restoration

The application, router, shell, and branch navigators all have restoration scopes. Each branch uses a stable navigator key. Retapping the active destination returns that branch to its initial route; selecting another destination restores its previous stack.

## Native link configuration

`scripts/configure_deep_links.py` idempotently adds:

- Android App Links and the `reemove` custom scheme
- Flutter deep-link metadata
- iOS Universal Links associated domains
- iOS custom URL scheme
- Runner entitlements and the Xcode entitlement build setting

Hosting templates live in `docs/app_links/`. Production fingerprints, Apple Team ID, bundle ID, and verified host must be finalized before release.
