# Onboarding platform setup

## Bootstrap

Run:

```bash
./scripts/bootstrap_project.sh
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID
```

The bootstrap script generates missing Flutter platform folders, runs `scripts/configure_native_permissions.py`, installs dependencies, and executes available validation.

## Android

The native configuration script declares:

- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.POST_NOTIFICATIONS`

Use a current Android compile SDK supported by the checked-in Flutter and plugin versions. Test location with both approximate and precise permission choices, and test notification behavior on Android 13+.

## iOS

The script adds these `Info.plist` purpose strings:

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSLocationWhenInUseUsageDescription`

It also sets `BYPASS_PERMISSION_LOCATION_ALWAYS=1` in the CocoaPods build settings so ReeMove requests only when-in-use location during this phase.

For notifications, enable **Push Notifications** and **Background Modes > Remote notifications** in the Runner target, upload/configure the APNs authentication key in Firebase, and test on a physical device.

## Firebase configuration

Deploy the Phase 4 backend and policies:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

The `app_config/mobile` document must contain at least:

```text
minimumAge: 13
maximumAge: 120
onboardingVersion: 1
termsVersion: "1.0"
privacyVersion: "1.0"
```

Every selectable `sports/{sportId}` document must have `isEnabled: true` before a user can complete onboarding with it.

## Local emulator identities

Start all configured emulators and keep them running:

```bash
npm run emulators:start
```

In a second terminal, seed the running Auth and Firestore emulators:

```bash
npm run seed:running-emulators
```

Two deterministic users are seeded:

```text
Completed account
Email: athlete@demo.reemove.app
Password: ReeMoveDemo123!

Incomplete account (opens onboarding)
Email: newcomer@demo.reemove.app
Password: ReeMoveDemo123!
```

Use only with the local `demo-reemove` emulator project.

## Required device test matrix

- Fresh email/password registration through all ten steps
- Google and Apple accounts requiring username setup before onboarding
- App termination and resume on every step
- Photo library, camera, canceled picker, and Android lost-data recovery
- Location granted precisely, granted approximately, denied, denied forever, and services disabled
- Notifications authorized, provisional where available, denied, and not requested
- Under-minimum-age rejection and legal-version mismatch
- Offline/interrupted progress save and retry
- Dark/light mode, large text, screen reader, RTL, keyboard, and small-screen layouts
- Completion race from two devices and repeated idempotent completion
