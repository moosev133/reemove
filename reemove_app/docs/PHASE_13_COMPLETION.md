# Phase 13 completion — Unified notifications

Phase 13 adds one production notification system across the cumulative ReeMove application while preserving the architecture delivered in Phases 1–12.

## Delivered

- Durable private Activity inbox with live unread count, filtering, pagination, read state, delete, and clear-read actions.
- Unified notification categories for social activity, messages, sports events, challenges, marketplace, account/safety, and optional product updates.
- Idempotent event processing and stable grouping so repeated backend events do not create duplicate inbox records.
- FCM delivery through registered per-device tokens, privacy-safe previews, invalid-token cleanup, and deep links into the correct application branch.
- Category preferences, master push switch, preview control, quiet hours, and per-conversation messaging settings.
- Quiet-hour deferral with scheduled delivery rather than silent loss.
- Recipient-visible and administrator-auditable delivery records.
- Trusted callable actions for preferences and inbox mutations; clients cannot forge notifications, counters, or delivery status.
- Triggers for follows, comments, reactions, messages, challenge submissions/reviews/rewards/reminders, event changes, and marketplace lifecycle updates.
- Firestore Rules, indexes, deterministic seed fixtures, backend policy tests, Dart mapping/preferences tests, and release documentation.

## Architecture result

A durable notification is created independently of whether the user grants push permission. The private inbox is therefore the source of truth, while FCM is an optional delivery channel. All modules call the same server notification service, which applies blocks, recipient status, category controls, preview privacy, quiet hours, grouping, idempotency, and delivery auditing.

Firestore and Firebase Messaging types remain in the data layer. The Flutter domain uses provider-neutral notification entities and preferences. Notification routes are constrained to local ReeMove paths before they are stored or opened.

## Exit-gate status

Phase 13 implementation is complete in source. Production enablement still requires Flutter analyzer/tests and native builds, physical-device FCM/APNs testing, complete executable Firebase Rules emulator tests, timezone/quiet-hours verification, notification permission and preview review on both platforms, and delivery/invalid-token monitoring in staging.

## Next phase

Phase 14 implements the provider-neutral AI gateway, coach, workout and nutrition planning, matchmaker, safe challenge generation, content assistant, trainer dashboard, prompt versions, quotas, evaluation, safety controls, and cost telemetry.
