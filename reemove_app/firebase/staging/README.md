# Staging native Firebase configs (gitignored)

Place regenerated files here (never commit):

- `android/app/src/staging/google-services.json`
- `ios/config/staging/GoogleService-Info.plist`
- `macos/config/staging/GoogleService-Info.plist`

Regenerate from the Flutter project root:

```bash
firebase apps:sdkconfig ANDROID <ANDROID_APP_ID> --project reemove-staging \
  -o android/app/src/staging/google-services.json
firebase apps:sdkconfig IOS <IOS_APP_ID> --project reemove-staging \
  -o ios/config/staging/GoogleService-Info.plist
cp ios/config/staging/GoogleService-Info.plist \
  macos/config/staging/GoogleService-Info.plist
```

Dart options for staging live in committed `lib/firebase_options_staging.dart`
and are selected only when `APP_FLAVOR=staging`.

Production FlutterFire files are not created in Stage 4.
