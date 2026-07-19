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
- [ ] Deploy Phase 8 messaging Functions, Firestore/Storage/Realtime Database rules, and indexes
- [ ] Configure FCM/APNs for message push notifications (see `docs/MESSAGING_SETUP.md`)
- [ ] Optionally set `FIREBASE_DATABASE_URL` for non-default Realtime Database instances
- [ ] Optionally seed emulator messaging fixtures (direct conversation, group, presence ACL)
- [ ] Deploy sports / nearby / challenges / marketplace / notifications / AI Functions, rules, and indexes per prior phase docs
- [ ] Configure Google Maps API keys for Android/iOS/web (never commit keys)
- [ ] Set Cloud Functions secret `OPENAI_API_KEY` for AI modules
- [ ] Enable Crashlytics and Performance Monitoring in Firebase console
- [ ] Sign Phase 15 `docs/RELEASE_READINESS_SCORECARD.md` before production launch

## Phase 16 — Production release (owner actions)

### Firebase environments
- [ ] Create isolated Firebase projects for development, staging, and production
- [ ] Copy `.firebaserc.example` → local `.firebaserc` and fill real project IDs (do not commit `.firebaserc`)
- [ ] Run FlutterFire configure per environment; keep `firebase_options.dart` and platform config files out of Git
- [ ] Publish Remote Config from `remoteconfig.template.json` before enabling Remote Config clients in prod
- [ ] Configure App Check (debug in dev; real providers in staging/prod — monitor then enforce) — see `docs/APP_CHECK_ROLLOUT.md`
- [ ] Configure Functions secrets/params per `docs/FUNCTIONS_PRODUCTION_CONFIG.md` (OpenAI, media processor, etc.)
- [ ] Point GitHub Environments (`staging`, `production`) at Workload Identity Federation secrets (`GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_FIREBASE_DEPLOYER_SERVICE_ACCOUNT`)
- [ ] Set `PUBLIC_STATUS_BASE_URL` repository variable when a public `/health` + `/version` status surface exists

### Android
- [x] Permanent Android/iOS/macOS application identity is `com.reemove.app`
- [ ] Register `com.reemove.app` in Play Console / Apple Developer / Firebase apps
- [ ] Create upload keystore; keep `android/key.properties` local only (see `android/key.properties.example`)
- [ ] Store CI secrets: `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PROD_DART_DEFINES_JSON`
- [ ] Enroll Play App Signing and complete store listing using `config/store_metadata/` + `config/privacy/play_data_safety.yaml`

### iOS
- [ ] Replace bundle identifier; finish capabilities in `docs/IOS_PRODUCTION_CAPABILITIES_CHECKLIST.md`
- [ ] Create distribution certificate + App Store profile; materialize `ios/ExportOptions.plist` from the template (do not commit)
- [ ] Store CI secret `IOS_EXPORT_OPTIONS_PLIST` (+ Apple signing mechanism of record)
- [ ] Complete App Store Connect privacy answers from `config/privacy/app_store_privacy_answers.yaml`

### Maps / AI / FCM
- [ ] Restrict Maps API keys by package/bundle and ship via CI secrets / dart-defines — never commit
- [ ] Confirm `OPENAI_API_KEY` is only in Secret Manager / Functions secrets
- [ ] Complete FCM + APNs for production apps and upload APNs key to Firebase
- [ ] Verify notification deep links against staging before production rollout

### Store / legal / ops
- [ ] Host privacy policy, terms, community guidelines, and account-deletion pages (start from `legal_templates/`)
- [ ] Fill SUPPORT_URL / STATUS_URL / STORE_URL in local `dart_defines/*.json` (never commit filled files)
- [ ] Rehearse backup/restore and rollback using `docs/BACKUP_RESTORE_DISASTER_RECOVERY.md` and `docs/ROLLBACK_INCIDENT_RESPONSE.md`
- [ ] Follow staged rollout in `config/release_channels.yaml` and `docs/STAGED_LAUNCH_RUNBOOK.md`
- [ ] Complete ownership handoff in `docs/OWNERSHIP_ACCESS_HANDOFF.md`

## Do not commit

- `.firebaserc` (real project IDs)
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `macos/Runner/GoogleService-Info.plist`
- `android/key.properties`, `*.jks`, `*.keystore`
- `ios/ExportOptions.plist` (use the `.template` only in Git)
- `dart_defines/*.json` (examples only)
- `.env` and other secret files
- Function or CI secrets / API keys / service-account JSON
