# Firebase Staging Setup — `reemove-staging`

**Scope:** Staging project only. Never apply these steps to `reemove-production` in this stage.  
**Do not deploy** rules, indexes, Functions, Hosting, or Storage rules from this stage.  
**Related:** `docs/FLUTTERFIRE_STAGING.md` (FlutterFire apps + Dart options).

---

## Stage 5 status — complete for cloud product setup

| Item | Status |
|------|--------|
| FlutterFire Android / iOS / Web apps | Done — `com.reemove.app` on staging |
| `lib/firebase_options_staging.dart` | Done — RTDB URL + Storage bucket + Google OAuth client IDs |
| Firestore API + `(default)` DB | **Ready** — Native @ **`eur3`** |
| Realtime Database | **Ready** — `europe-west1` |
| Cloud Storage | **Ready** — `reemove-staging.firebasestorage.app` @ **`EUROPE-WEST1`** |
| Remote Config | **Ready** — 16 params published via REST |
| Crashlytics API + iOS/macOS symbol scripts | **Ready** — first crash/symbol upload completes Console onboarding |
| Authentication — Email / Password | **Enabled** |
| Authentication — Google | **Enabled** — debug SHA-1/256 registered; `GOOGLE_SERVER_CLIENT_ID` in dart-defines |
| Authentication — Apple | **Provider enabled** in Firebase (see deferred notes) |
| Production project | Untouched (**0 apps**) |

### Staging resource IDs

| Resource | Value |
|----------|-------|
| Project | `reemove-staging` (`377819651760`) |
| Firestore | `projects/reemove-staging/databases/(default)` @ `eur3` |
| RTDB | `https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app` |
| Storage | `gs://reemove-staging.firebasestorage.app` (`EUROPE-WEST1`) |
| Web OAuth (server) client | `377819651760-hk7v3j1stqame8jqnmkdak6er2dti6r9.apps.googleusercontent.com` |

Local dart-defines: copy `dart_defines/staging.json.example` → `dart_defines/staging.json` (gitignored).

---

## Deferred (not Stage 5 blockers; no Firebase Console required now)

These are **later-stage** or Apple Developer portal work — Stage 5 cloud services are configured.

1. **Apple Sign-In runtime (Apple Developer / Xcode)**  
   Firebase Apple provider is enabled. For real iOS sign-in: enable Sign in with Apple on App ID `com.reemove.app`, entitlement in Xcode.  
   For **web/Android** Apple Sign-In: add Services ID / Team ID / Key ID / private key under Firebase Apple provider (code-flow config is currently empty). Never commit those secrets.

2. **iOS Google URL scheme**  
   Add `REVERSED_CLIENT_ID`  
   (`com.googleusercontent.apps.377819651760-sv5p1vgk4313ier40n5m1773uliflf3s`)  
   to Runner `Info.plist` `CFBundleURLTypes` when exercising iOS Google Sign-In (kept out of committed plist while production OAuth is unset).

3. **Release / upload keystore SHA certs** — register before shipping Android releases.

4. **APNs, Maps, App Check enforcement, rules/Functions/Hosting deploy** — explicitly out of Stage 5.

5. **Crashlytics Console** — optional one-time open; onboarding finishes on first crash/symbol upload.

---

## Service dependency matrix

| Service | Required | Implemented in app | Staging status | Notes |
|---------|----------|--------------------|----------------|-------|
| Authentication (Email, Google, Apple) | Required | Yes | **Providers on** | Apple Developer / code-flow later |
| Cloud Firestore | Required | Yes | **Ready** | Rules deploy later |
| Cloud Storage | Required | Yes | **Ready** | Rules deploy later |
| Realtime Database | Required | Yes | **Ready** | Rules deploy later |
| Cloud Functions | Required | Yes (`europe-west1`) | Later | Do **not** deploy in Stage 5 |
| Cloud Messaging (FCM) | Required | Yes | Apps registered | APNs deferred |
| Remote Config | Required | Yes | **Published** | 16 params |
| App Check | Later | Yes (gated) | Do **not** enforce | |
| Analytics | Optional | Yes (gated) | Optional | |
| Crashlytics | Required (mobile) | Yes | API + symbol scripts | |
| Performance Monitoring | Recommended | Yes | Optional | |
| Hosting | Not used by app | No | Skip | |
| Maps | Non-Firebase | Nearby UI | Out of scope | |

---

## Local / FlutterFire

- Staging Dart options: `lib/firebase_options_staging.dart` → `StagingFirebaseOptions`
- Native files (gitignored): `android/app/src/staging/`, `ios/config/staging/`, `macos/config/staging/`
- `firebase.json` → `flutter.platforms` points at staging-only outputs

```bash
flutter run -d chrome --dart-define-from-file=dart_defines/staging.json
```

Or:

```bash
flutter run -d chrome \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define=FIREBASE_DATABASE_URL=https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=377819651760-hk7v3j1stqame8jqnmkdak6er2dti6r9.apps.googleusercontent.com
```

---

## Explicitly out of scope (Stage 5)

- Production (`reemove-production`) configuration
- Any `firebase deploy` (rules, functions, hosting, indexes)
- Maps, App Check enforcement, APNs
- Deploying Storage / RTDB / Firestore security rules from the repo
