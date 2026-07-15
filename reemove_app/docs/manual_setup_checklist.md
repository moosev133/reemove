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
- [ ] Optionally seed the Firebase emulator
- [ ] Install/configure Xcode before testing iOS or macOS
- [ ] Configure Google Sign-In (OAuth client IDs / `GOOGLE_SERVER_CLIENT_ID`)
- [ ] Configure Apple Sign-In capability for iOS/macOS builds

## Do not commit

- `.firebaserc` (real project IDs)
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `.env` and other secret files
- Function or CI secrets / API keys
