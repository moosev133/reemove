# Unified notifications implementation

## Goals

Phase 13 provides one private, reliable notification system for every ReeMove module. The durable Activity inbox is authoritative; push notifications are a best-effort delivery channel governed by user preferences and device permission.

## Data flow

1. A trusted callable, scheduled job, or Firestore trigger identifies a meaningful product event.
2. `createAndDeliverNotification` validates the recipient, reciprocal blocks, category, route, preview, and event identifier.
3. A server-only event marker makes processing idempotent.
4. A notification is created or merged into a stable group under `users/{uid}/notifications`.
5. The private unread summary is updated transactionally.
6. Push delivery is skipped, delivered, or deferred according to account preferences, conversation settings, quiet hours, and valid device tokens.
7. Every delivery attempt is recorded under `notification_deliveries`.

## Grouping and idempotency

Notifications use a category/entity group key plus a bounded time bucket. Repeated activity can update one inbox row with the latest actor, body, timestamp, and group count instead of flooding the user. Every source event also has a private hash record under `notification_events`; retries return the prior result without incrementing unread state twice.

## Preference model

The private preferences record supports:

- master push enablement;
- lock-screen preview visibility;
- social activity;
- messages;
- sports events;
- challenges;
- marketplace;
- account and safety notices;
- optional product updates;
- quiet-hours start, end, enablement, and current UTC offset.

The Activity inbox remains available even when push is disabled. Account and safety notices are still recorded durably, while the user-controlled push category determines external delivery.

## Quiet hours

Quiet hours may cross midnight. Eligible push deliveries are stored with `status = deferred` and `deliverAfter`. A scheduled Function drains due deliveries in bounded batches. The underlying inbox item is visible immediately, and no push is silently discarded.

## Privacy and safety

- Notification documents are readable only by their recipient.
- Event idempotency records, unread counters, preferences mutations, and notification writes are server-owned.
- Preview text can be replaced with a generic message when previews are disabled.
- Routes must be local application paths; external URLs are rejected.
- Blocked relationships suppress applicable notifications.
- Messages also honor per-conversation mute and notification settings.
- Device tokens are private and invalid tokens are removed after provider errors.
- Delivery records are readable only by the recipient or an administrator and are never client-writable.

## Flutter implementation

- `NotificationRepository` is the domain boundary.
- `FirebaseNotificationRepository` streams the inbox, summary, and preferences and invokes trusted callables for changes.
- Riverpod providers expose live inbox rows, unread badge state, preferences, foreground messages, and notification-open routes.
- `ActivityScreen` supports category filters, refresh, pagination, mark-read, delete, and clear-read actions.
- `NotificationSettingsScreen` controls categories, previews, and quiet hours.
- `AppShell` routes foreground/background notification opens through GoRouter and shows privacy-safe foreground banners.

## Backend coverage

The unified pipeline currently receives events from:

- direct and group messages;
- new followers and private-profile requests;
- post comments, likes, and reposts;
- challenge proof submissions and reviews;
- challenge rewards and opted-in reminders;
- sports-event attendance/status changes;
- marketplace listing moderation and lifecycle changes.

Future modules should call the same service rather than sending FCM directly.
