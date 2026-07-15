# Authentication implementation

## Scope

Phase 3 implements ReeMove's complete account-access foundation:

- Email/password registration and sign-in
- Google and Apple sign-in
- Unique usernames
- Email verification and password reset
- Account/provider linking
- Session restoration and guarded routing
- Reauthentication and account-wide session revocation
- Account deletion with retry recovery
- Legal-consent recording
- Server-side abuse controls and audit events
- Privacy-safe authentication analytics
- Emulator-ready local development

## Architecture

```text
Flutter screen
  -> AuthActionController
  -> domain repository/service contract
  -> Firebase data implementation
  -> Firebase Authentication / callable Function / Firestore / Analytics
```

Firebase SDK types never enter domain entities. `FirebaseUserMapper` converts Firebase identities into `AuthUser`; Firebase Auth and Functions exceptions are converted to typed `Failure` objects before presentation receives them.

## Account creation

### Email/password

1. The client validates display name, username, email, password, and legal confirmations.
2. Firebase Authentication creates the identity.
3. The client calls `provisionAccount`.
4. The callable validates authentication and App Check, then consumes a server-side rate-limit budget.
5. A Firestore transaction checks the normalized username reservation.
6. The transaction creates `usernames/{username}`, `users/{uid}`, `users/{uid}/private/profile`, and `users/{uid}/private/consents`.
7. The client requests an email-verification message.
8. The typed router moves password users to the verification gate.

If profile provisioning fails after creating a new email identity, the client attempts to delete the newly created Auth user as a rollback.

### Google or Apple

1. Firebase completes federated authentication.
2. If no public profile exists, routing sends the user to username setup.
3. The same trusted callable provisions the account atomically.
4. Provider metadata is synchronized from Firebase Admin, not trusted from the client.
5. The user continues to Phase 4 onboarding.

## Username policy

- Lowercase and trimmed normalization.
- Length of 3–30 characters.
- Lowercase letters, numbers, dots, and underscores only.
- Must begin and end with a letter or number.
- Repeated separators are rejected.
- Reserved system names are rejected on client and server.
- Direct client writes and collection listing are denied.
- Exact document reads support responsive availability feedback.
- The server transaction remains authoritative against races.

## One guarded routing state

`authRoutingStateProvider` combines Firebase identity and the typed public profile into one destination:

- `configurationRequired`
- `signedOut`
- `profileRequired`
- `emailVerificationRequired`
- `onboardingRequired`
- `ready`
- `blocked`

During account provisioning, routing remains loading so GoRouter cannot interrupt the transaction and redirect to username setup prematurely.

## Account linking

The account-security screen can link any missing supported method:

- Email/password via `linkWithCredential`
- Google through the platform identity adapter and Firebase credential
- Apple through Firebase's provider flow

After a successful link, `syncAuthProviders` reads provider data from Firebase Admin and writes only normalized provider IDs to `users/{uid}/private/profile`. This prevents a client from inventing provider state and avoids duplicate ReeMove profiles for the same Firebase identity.

## Reauthentication and session revocation

Sensitive operations reauthenticate with a provider already linked to the account. The backend independently validates the ID token's `auth_time` against a ten-minute window.

`revokeSessions` then:

1. Applies a server-side rate limit.
2. Calls Firebase Admin refresh-token revocation.
3. Stores `sessionsRevokedAt` in owner-readable/server-writable private metadata.
4. Writes an audit event.
5. Returns success so the initiating device can terminate its local Firebase session.

Other devices are forced to authenticate again when their existing ID token expires and they attempt to refresh it.

## Account deletion

`deleteAccount`:

1. Requires authentication and recent sign-in.
2. Applies a strict daily rate limit.
3. Creates or updates `account_deletions/{uid}`.
4. Disables the Auth identity first to block new sessions while preserving a retryable identity.
5. Recursively deletes the implemented user document tree.
6. Releases the username only when the reservation belongs to the same UID.
7. Deletes the Firebase Authentication identity last.
8. Marks the workflow completed or failed and records a privileged audit event.

`retryAccountDeletions` runs every six hours for `processing` or `failed` records. Later content phases must register cleanup/anonymization for posts, messages, activities, events, listings, and Storage assets before those features reach production.

## Abuse controls and server audit

`consumeRateLimit` uses a Firestore transaction on `rate_limits/{uid}_{action}`. Current policies cover provisioning, provider sync, session revocation, and deletion. The collection is server-only and includes an expiry timestamp for future Firestore TTL cleanup.

`writeAuditEvent` writes immutable server-only events to `audit_logs`. Audit writes are best effort so an observability outage cannot roll back an already completed identity mutation; failures remain visible in Cloud Functions logs.

## Analytics and privacy

The client emits only action/provider categories such as login, sign-up, provider link, verification request, password-reset request, session revocation, and deletion request. It never includes email addresses, usernames, names, raw UIDs, passwords, credentials, or tokens.

Analytics is disabled by default, disabled in emulator mode, and enabled only with:

```bash
--dart-define=ENABLE_ANALYTICS=true
```

A production launch must align this switch with the app's consent/privacy configuration and store declarations.

## Failure handling

`FirebaseAuthFailureMapper` maps invalid credentials, account collisions, linked-provider collisions, cancellation, weak passwords, recent-login requirements, rate limits, network/service failures, and malformed callable responses into user-safe messages. Stack traces and provider details are not exposed in the UI.
