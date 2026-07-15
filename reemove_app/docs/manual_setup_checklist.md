# Manual setup checklist

Pending configuration that must be completed outside Git before Firebase-backed features can run in real environments. Do **not** commit secrets or generated Firebase credentials.

## Pending

- [ ] Run FlutterFire configure
- [ ] Generate `firebase_options.dart`
- [ ] Add Android and iOS Firebase platform files (`google-services.json`, `GoogleService-Info.plist`)
- [ ] Replace the placeholder `.firebaserc` with the real Firebase project ID
- [ ] Install dependencies inside `functions/`
- [ ] Install dependencies inside `firebase_tests/`
- [ ] Run Firebase rules tests before deployment
- [ ] Optionally seed the Firebase emulator (completed + incomplete onboarding demo users)
- [ ] Install/configure Xcode before testing iOS or macOS
- [ ] Configure Google Sign-In (OAuth client IDs / `GOOGLE_SERVER_CLIENT_ID`)
- [ ] Configure Apple Sign-In capability for iOS/macOS builds
- [ ] Run `scripts/configure_native_permissions.py` (or `./scripts/bootstrap_project.sh`) for location/camera/photos/notification permissions
- [ ] Android: confirm `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, and `POST_NOTIFICATIONS` are declared
- [ ] iOS: confirm Info.plist strings for camera, photo library, and when-in-use location; enable Push Notifications + Background Modes → Remote notifications
- [ ] Deploy Phase 4 Functions, Firestore rules/indexes, and Storage rules before testing completion flows
- [ ] Ensure `app_config/mobile` includes `minimumAge`, `maximumAge`, `onboardingVersion`, `termsVersion`, and `privacyVersion`
- [ ] Ensure enabled `sports/{sportId}` documents exist for favorite-sport selection

## Do not commit

- `.firebaserc` (real project IDs)
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `.env` and other secret files
- Function or CI secrets / API keys
