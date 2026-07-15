# Environment and Firebase Setup

## Project model

Use three isolated projects such as:

- `reemove-dev`
- `reemove-staging`
- `reemove-prod`

Actual IDs must be owned by the ReeMove organization and may differ. Use `.firebaserc` aliases rather than hard-coding IDs into scripts.

## Production checklist

### Authentication

- Enable Email/Password, Google, and Apple only after callback domains, consent screens, and credentials are final.
- Configure authorized domains and email templates.
- Prevent account enumeration where supported.
- Test provider linking, revoked credentials, disabled users, and deletion.

### Firestore

- Deploy deny-by-default rules before client distribution.
- Deploy indexes before enabling features that require them.
- Enable point-in-time recovery/backup strategy appropriate to the selected Firebase/Google Cloud plan.
- Define data TTL only for collections where automatic deletion is intentional and tested.

### Storage

- Merge final Storage rules and validate content type, ownership, size, and path constraints.
- Apply lifecycle policies only to derived/temp objects, never blindly to user originals.
- Confirm moderation and deletion cascades cover avatars, posts, stories, chat attachments, listings, and AI artifacts.

### Functions

- Use 2nd generation functions where selected by the architecture.
- Set region, memory, concurrency, min/max instances, timeout, and retry behavior explicitly.
- Store API secrets in Secret Manager or typed parameters; do not ship them in Flutter or `.env` files committed to Git.
- Configure budget alerts and quotas for AI, maps, storage, egress, and callable abuse.

### FCM/APNs

- Upload/associate APNs credentials in the production Firebase project.
- Verify Android notification channels and iOS notification permissions.
- Test deep links from foreground, background, and terminated states.
- Remove invalid tokens and honor user notification preferences/quiet hours.

### App Check

- Android: Play Integrity provider.
- Apple: App Attest, with an approved fallback strategy where needed.
- Start in metrics/monitor mode, fix invalid traffic, then enforce product by product.
- Never reuse debug tokens in production builds.

### Observability

- Crashlytics: verify test crash, non-fatals, custom keys, symbol upload, and PII-safe logging.
- Performance: verify startup/network/custom traces and sampling behavior.
- Analytics: collect only approved events after consent rules are applied.
- Remote Config: publish safe in-app defaults and emergency overrides before launch.

## Maps keys

Create separate keys per platform and environment. Restrict Android keys by package name and signing certificate, Apple keys by bundle identifier, and server keys by API/service/IP or workload identity as applicable. Enable only required APIs.
