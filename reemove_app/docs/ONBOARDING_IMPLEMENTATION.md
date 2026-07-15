# Phase 4 onboarding implementation

## Scope

Phase 4 replaces the authentication handoff with a production onboarding flow. The flow is resumable, permission-aware, privacy-minimized, and completed only by trusted backend code.

## User flow

The single guarded `/onboarding` route renders ten persisted steps:

1. Profile photo and reserved username confirmation
2. Private birthday and age policy
3. Favorite sports
4. Skill level for every selected sport
5. Personal goals
6. Optional location permission and capture
7. Discovery radius and visibility
8. Accessibility preferences
9. Optional notification permission and categories
10. Review and trusted completion

The current step is stored after every successful Continue or Back action. Reopening the app restores the exact step and values from `users/{uid}/private/onboarding`.

## Architecture

```text
OnboardingFlowScreen
  -> OnboardingController (Riverpod AsyncNotifier)
    -> OnboardingRepository / AvatarRepository / permission services
      -> Firestore + Callable Functions + Storage + platform SDKs
```

Domain entities contain no Firebase or platform SDK types. `OnboardingDraftDto` performs serialization at the data boundary. The presentation layer never calls Firebase directly.

## Trusted persistence

### `saveOnboardingProgress`

- Requires Firebase Authentication and App Check.
- Applies a transaction-backed per-user rate limit.
- Parses and normalizes the complete draft.
- Rejects unsupported onboarding versions.
- Stores the draft under the user's private subcollection.
- Refuses changes after onboarding is already complete.
- Writes a minimized privileged audit event.

### `completeOnboarding`

- Revalidates every mandatory field on the server.
- Reads the active app age/legal policy.
- Verifies that selected sports exist and are enabled.
- Verifies avatar path, owner metadata, content type, size, and URL/path agreement.
- Verifies current legal-consent versions.
- Derives age band and minor status without publishing birthday.
- Accepts exact location only when permission is `granted`.
- Writes coarse public location and exact private location separately.
- Derives notification master enablement from the recorded OS permission status.
- Atomically updates public profile, private profile, preferences, and onboarding state.
- Sets the server-owned `onboardingCompleted` marker and version.

Clients cannot write private onboarding documents or completion/profile personalization fields directly; Firestore Rules force them through the callable Functions.

## Location privacy

Exact coordinates and a precision-9 geohash live only in `users/{uid}/private/preferences`. The public profile stores coordinates rounded to two decimal places with a precision-6 geohash. If permission is not granted, trusted completion removes any stale public location fields and writes `exactLocation: null` privately.

This separation supports nearby discovery without publishing a user's precise device location.

## Avatar pipeline

- Uses camera or photo library through `image_picker`.
- Recovers Android lost picker results after process recreation.
- Resizes/compresses requested images before upload.
- Enforces a client and Storage Rules limit below 10 MB.
- Uploads to `users/{uid}/avatar/{assetId}` with owner/schema metadata.
- Verifies metadata again in `completeOnboarding`.
- Deletes the previous avatar as a best-effort cleanup after a successful replacement.

## Permission strategy

Location and notifications are requested only after an explicit user action on the relevant step. Denial never blocks onboarding. Permanent denial and disabled location services expose direct settings actions. Emulator mode uses an unavailable notification service so local development does not trigger real push-permission dialogs.

## Validation

Validation exists at three layers:

- Presentation/application validation for immediate feedback.
- Callable request parsing for strict type, enum, list-size, and range validation.
- Completion policy validation against server-owned config, sports, consents, Storage metadata, and account state.

The server remains authoritative even if a modified client bypasses local validation.
