# Notifications setup and release guide

## Firebase configuration

1. Enable Firebase Cloud Messaging for the development, staging, and production Firebase projects.
2. Keep platform Firebase configuration files outside public source-control workflows where required.
3. Configure iOS Push Notifications and Background Modes in Xcode.
4. Upload the APNs authentication key to Firebase for each Apple bundle/environment.
5. Confirm Android notification permission behavior on Android 13+ and create production notification-channel policy if custom channels are introduced.
6. Deploy Firestore Rules, indexes, Functions, and scheduled jobs before enabling notification-trigger traffic.

## Required deployments

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

The scheduled quiet-hours flush and cleanup Functions require a Firebase project/billing plan that supports scheduled Functions.

## Device verification matrix

Test on physical devices for:

- Android foreground, background, terminated, and permission-denied states;
- iOS foreground, background, terminated, provisional/denied/authorized states;
- APNs token registration and token refresh;
- sign-out and account-deletion token cleanup;
- invalid-token removal;
- grouped notifications;
- preview on/off behavior;
- quiet hours crossing midnight and daylight/timezone changes;
- muted conversation behavior;
- deep links into every completed module;
- blocked-account suppression;
- multiple devices on one account;
- mark-read and unread-badge synchronization.

## Operational monitoring

Monitor:

- delivery attempts by `status` and `errorCode`;
- deferred delivery age and queue depth;
- invalid-token removal rate;
- duplicate-event rate;
- notification creation and push latency;
- unread-summary reconciliation failures;
- Function retry volume;
- FCM/APNs provider errors;
- unexpected notification category or route validation failures.

Create alerts for a growing deferred queue, elevated permanent provider failures, or repeated delivery retries.

## Security release gates

Before staging approval:

- execute the full Firestore, Storage, and Realtime Database emulator Rules suite;
- verify App Check enforcement on callable and trigger-adjacent workflows;
- verify users cannot write notification, event marker, delivery, summary, or preference records directly;
- confirm admin claims are required for cross-user delivery audit access;
- review message and sensitive-account preview wording;
- test reciprocal block and account-disabled behavior;
- confirm no raw FCM/APNs tokens appear in logs or analytics.

## Local/emulator notes

Seed data includes private Activity rows, an unread summary, notification preferences, and a delivery audit. FCM provider delivery is not meaningfully emulated end to end; use a restricted staging Firebase project and physical devices for final push verification.
