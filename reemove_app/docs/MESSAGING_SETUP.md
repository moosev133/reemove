# Messaging platform setup

Complete this guide separately in development, staging, and production.

## 1. Enable Firebase services

Enable:

- Cloud Firestore
- Realtime Database
- Firebase Storage
- Cloud Functions in the configured region
- Firebase Cloud Messaging
- App Check for Firestore, Realtime Database, Storage, and callable Functions

Deploy the included configuration:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,database,functions
```

## 2. Realtime Database URL

Mobile Firebase configuration normally resolves the default database automatically. For web, secondary databases, or explicit environment isolation, pass:

```bash
--dart-define=FIREBASE_DATABASE_URL=https://YOUR_PROJECT_ID-default-rtdb.REGION.firebasedatabase.app
```

Never point a production build at an emulator or a database belonging to another environment.

## 3. Android FCM

- Add the correct `google-services.json` for each flavor.
- Confirm the package name matches Firebase.
- Keep `POST_NOTIFICATIONS` for Android 13+; the native permission script adds it.
- Configure a default notification icon/color in `AndroidManifest.xml` after native projects are generated.
- Test foreground, background, terminated, token rotation, reinstall, and notification-tap flows on a physical device.

The server uses the platform default notification channel. Add a custom Android channel only together with client-side channel creation.

## 4. Apple push notifications

In Apple Developer and Xcode:

1. Enable Push Notifications for the App ID.
2. Add the Push Notifications capability to Runner.
3. Add Background Modes and enable Remote notifications.
4. Upload an APNs authentication key to Firebase Cloud Messaging.
5. Confirm the bundle identifier and provisioning profile match the Firebase iOS app.
6. Test on a physical device; the iOS Simulator is not sufficient for all APNs behavior.

## 5. User permission

Notification permission is requested from the explicit onboarding preference step. Device tokens are registered only when the operating-system status is authorized or provisional. Users may disable a conversation independently through its details screen.

## 6. Emulator workflow

Start the configured emulators:

```bash
npm run emulators:start
```

Seed Auth, Firestore, and Realtime Database in another terminal:

```bash
npm run seed:running-emulators
```

Run Flutter:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=USE_FIREBASE_EMULATORS=true \
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1 \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false
```

The seed creates a direct conversation between the completed athlete and runner accounts plus a three-person Weekend Training group.

## 7. Rules and backend verification

Before staging deployment:

```bash
npm --prefix functions ci
npm --prefix firebase_tests ci
npm run verify:backend
```

The Rules tests require Java and downloaded Firestore/Storage/Realtime Database emulator binaries.

## 8. Required release tests

- Direct conversation idempotency.
- Private-account and block enforcement.
- Group create, rename, add, remove, leave, and owner/admin restrictions.
- Text and media sends under slow, interrupted, and restored networks.
- Duplicate client-message retries.
- Read receipts with multiple devices.
- Typing and presence disconnect cleanup.
- Mute, archive, notification preference, and token refresh.
- Background and terminated notification taps.
- Attachment access immediately after member removal.
- Report creation, moderation visibility, and rate limiting.
- Text scaling, RTL, screen reader, keyboard, and tablet layouts.
