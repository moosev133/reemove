# Security and Privacy Testing

Use the OWASP Mobile Application Security Verification Standard and Testing Guide as the baseline, adapted to ReeMove's risk profile.

## Threat model

Protect:

- Credentials, session tokens, App Check tokens, push tokens, API keys, and signing material
- Private profiles, messages, media, location, challenge proof, marketplace conversations, reports, and AI history
- Admin/trainer privileges and server-authoritative metrics
- Integrity of challenge rankings, follows, unread counts, marketplace ownership, and AI quotas

Threat actors include unauthenticated callers, abusive users, blocked users, modified clients, replaying clients, compromised devices, leaked tokens, malicious links, and accidental developer misconfiguration.

## Required tests

### Authentication and session

- Token expiry/refresh, disabled/deleted users, provider linking, account enumeration resistance, sign-out cleanup, multi-device behavior, and privileged custom claims.

### Authorization

- Cross-user reads/writes for every private collection
- Group/chat membership changes
- Ownership transfer attempts
- Blocked-user access
- Admin/trainer claim spoofing
- Direct writes to server-only counters, audit logs, AI outputs, usage, rankings, rewards, notification delivery state, and moderation records

### Input and content

- Length/type/range validation
- Unexpected fields
- Unicode and RTL edge cases
- Malformed deep links
- File type/size/metadata validation
- Stored content rendering without code execution
- Server timestamps and immutable ownership fields

### Mobile storage and logs

- No secrets in source, assets, logs, crash reports, screenshots, clipboard, backups, or local plaintext storage
- Sensitive caches cleared on sign-out/account deletion
- Debug endpoints and debug App Check tokens absent from release builds

### Network and backend

- TLS-only traffic
- No production emulator hosts
- Callable auth/App Check enforcement
- Replay/idempotency behavior
- Rate limiting and abuse controls
- Least-privilege service accounts
- Secret Manager usage
- CORS only where relevant and narrowly configured

### Deep links and push

- Validate scheme, host, route, identifiers, and authorization after navigation
- Do not trust notification payloads as proof of access
- Deleted/private/blocked target produces a safe not-found state

## Privacy tests

- Data minimization and consent for location, contacts, camera, photos, notifications, analytics, crash reporting, and performance monitoring
- Approximate rather than precise location where the feature permits it
- Correct privacy visibility on feed, nearby, challenges, marketplace, and AI history
- Account deletion removes or anonymizes data according to policy
- Retention jobs and audit access are tested
- Analytics and logs contain IDs only when necessary and never message bodies, precise location, health details, or AI prompts by default

## Security release blockers

- Unauthorized private data access
- Unauthorized write to server-authoritative data
- Exposed secret or signing credential
- Privilege escalation
- App Check bypass accepted where enforcement is required
- High-confidence account takeover path
- Unsafe deep link enabling unauthorized action
- Confirmed critical/high issue without approved risk treatment
