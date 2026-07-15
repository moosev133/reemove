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
- [x] Android: `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, and `POST_NOTIFICATIONS` declared in the app manifest
- [x] iOS: Info.plist camera, photo library, and when-in-use location usage strings applied
- [ ] Re-run `scripts/configure_native_permissions.py` after regenerating native folders (idempotent); enable Push Notifications + Background Modes → Remote notifications in Xcode
- [ ] Deploy Phase 4 Functions, Firestore rules/indexes, and Storage rules before testing completion flows
- [ ] Ensure `app_config/mobile` includes `minimumAge`, `maximumAge`, `onboardingVersion`, `termsVersion`, and `privacyVersion`
- [ ] Ensure enabled `sports/{sportId}` documents exist for favorite-sport selection

- [ ] Configure deep links: `python3 scripts/configure_deep_links.py --host links.reemove.app` (or via bootstrap with `APP_LINK_HOST`)
- [ ] Host `docs/app_links/assetlinks.json` and `apple-app-site-association.json` on the verified HTTPS link host
- [ ] Replace SHA-256 fingerprints and Apple Team ID placeholders in app-link verification files
- [ ] Enable Android App Links / iOS Associated Domains for the production link host
- [ ] Deploy Phase 6 feed Functions, Firestore rules/indexes, and Storage rules (posts, stories, feed_entries, reactions, media paths)
- [ ] Configure media processor secrets/URLs (`MEDIA_PROCESSOR_URL`, `MEDIA_PROCESSOR_CALLBACK_URL`, `MEDIA_PROCESSOR_SECRET`) — see `docs/MEDIA_PROCESSING_SETUP.md`
- [ ] Optionally seed emulator feed fixtures (posts, reels, stories, comments, reactions)
- [ ] Deploy Phase 7 profile Functions, Firestore rules/indexes, and Storage rules (follow graph, verification, cover uploads, locked public user reads)
- [ ] Configure verification admin review workflow (see `docs/PROFILE_VERIFICATION_SETUP.md`)
- [ ] Optionally seed emulator profile fixtures (followers, follow requests, privacy settings, verification)

## Do not commit

- `.firebaserc` (real project IDs)
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `.env` and other secret files
- Function or CI secrets / API keys
