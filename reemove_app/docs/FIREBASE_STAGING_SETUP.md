# Firebase Staging Setup — `reemove-staging`

**Scope:** Staging project only. Never apply these steps to `reemove-production` in this stage.  
**Do not deploy** rules, indexes, Functions, Hosting, or Storage rules from this stage.  
**Related:** `docs/FLUTTERFIRE_STAGING.md` (FlutterFire apps + Dart options).

---

## Stage 5 status (after gcloud auth)

| Item | Status |
|------|--------|
| FlutterFire Android / iOS / Web apps | Done — `com.reemove.app` on staging |
| `lib/firebase_options_staging.dart` | Done — includes RTDB `databaseURL` |
| `gcloud` authenticated | Done (`meliodasin14@gmail.com`) |
| Firestore API | **Enabled** |
| Firestore `(default)` | **Created** — Native, location **`eur3`**, free tier |
| Realtime Database | **Created** — `europe-west1`, URL below |
| Remote Config | **Published** — 16 params from `remoteconfig.template.json` (REST, not `firebase deploy`) |
| Crashlytics API | **Enabled** (`firebasecrashlytics.googleapis.com`); iOS/macOS symbol upload phases wired by FlutterFire |
| Cloud Storage default bucket | **Blocked** — requires billing (Blaze); **not** enabled (owner rule: no billing) |
| Authentication | **Initialized** by owner in Console (Get started) |
| Auth — Google | **Enabled** — OAuth clients in configs; debug SHA-1/256 registered via CLI; `GOOGLE_SERVER_CLIENT_ID` in dart-defines |
| Auth — Email / Apple | Email: owner Console toggle; Apple: **Console only** (Apple Developer credentials) |
| Production project | Untouched (**0 apps**) |

### Staging resource IDs (created)

| Resource | Value |
|----------|-------|
| Project | `reemove-staging` (`377819651760`) |
| Firestore | `projects/reemove-staging/databases/(default)` @ `eur3` |
| RTDB | `https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app` |
| Storage bucket (expected once billing allowed) | `reemove-staging.firebasestorage.app` (referenced in FlutterFire options; **bucket not created yet**) |

Copy the RTDB URL into local `dart_defines/staging.json` as `FIREBASE_DATABASE_URL` (see `dart_defines/staging.json.example`).

---

## STOP — remaining owner console actions

Complete these in [Firebase Console](https://console.firebase.google.com/) → **ReeMove Staging** (`reemove-staging`).  
Do **not** enable billing unless you explicitly decide to (Storage creation currently requires Blaze).

### 1. Authentication — Email / Password — **DONE**

Verified via Admin API: email sign-in enabled (password required), authorized domains
`localhost`, `reemove-staging.firebaseapp.com`, `reemove-staging.web.app`.

### 2. Authentication — Google — **DONE**

Enabled by owner in Console. Completed automatically afterwards:

- Debug keystore **SHA-1 + SHA-256** registered on the staging Android app via Firebase CLI.
- FlutterFire config regenerated; native files now carry the OAuth clients
  (Android client, iOS client incl. `REVERSED_CLIENT_ID`, Web client).
- Web client ID `377819651760-hk7v3j1stqame8jqnmkdak6er2dti6r9.apps.googleusercontent.com`
  wired as `GOOGLE_SERVER_CLIENT_ID` in `dart_defines/staging.json` (+ example).

**Pending (release keys, later stage):** register upload/release keystore SHA certs before shipping.  
**Pending (iOS, later stage):** add the `REVERSED_CLIENT_ID` URL scheme
(`com.googleusercontent.apps.377819651760-sv5p1vgk4313ier40n5m1773uliflf3s`) to the iOS
Runner `Info.plist` `CFBundleURLTypes` when iOS Google Sign-In is exercised — deferred to
keep committed `Info.plist` flavor-neutral until production OAuth exists.

### 3. Authentication — Apple

**Path:** Sign-in method → **Apple** → Enable.

Requires Apple Developer Services ID, Team ID, Key ID, and private key (never commit). Bundle ID `com.reemove.app`. Complete Sign in with Apple capability in Apple Developer / Xcode.

### 4. Cloud Storage — default bucket (**billing decision**)

**Blocked without Blaze.** Creating `gs://reemove-staging.appspot.com` / Firebase default bucket failed with billing absent.

When you **explicitly** allow billing for staging only:

1. Link a billing account to `reemove-staging` (not production unless intended).
2. Firebase Console → Storage → Get started (or default-bucket API).
3. Prefer location aligned with EU (`eur3` / `europe-west1`).
4. **Do not** deploy repo `storage.rules` in Stage 5.

Until then, Storage SDK calls against staging will fail; FlutterFire already references `reemove-staging.firebasestorage.app`.

### 5. Crashlytics — open product in Console

API is enabled. Open Build → **Crashlytics** → enable for the Android/iOS apps if prompted. First crash/symbol upload finishes onboarding. APNs still deferred.

### 6. Optional verify Remote Config

Engage → **Remote Config** — confirm 16 parameters published (maintenance, force-update, feature flags, support/status URLs). Re-publish later if you change `remoteconfig.template.json` (prefer REST/console; avoid accidental full `firebase deploy`).

---

## Service dependency matrix

| Service | Required | Implemented in app | Staging status | Notes |
|---------|----------|--------------------|----------------|-------|
| Authentication (Email, Google, Apple) | Required | Yes | **Owner console** | Get started + providers |
| Cloud Firestore | Required | Yes | **Ready** | `eur3`; rules deploy later |
| Cloud Storage | Required | Yes | **Blocked (billing)** | Bucket not created |
| Realtime Database | Required | Yes | **Ready** | `europe-west1`; set dart-define |
| Cloud Functions | Required | Yes (`europe-west1`) | Later | Do **not** deploy in Stage 5 |
| Cloud Messaging (FCM) | Required | Yes | Apps registered | APNs deferred |
| Remote Config | Required | Yes | **Published** | 16 params |
| App Check | Later | Yes (gated) | Do **not** enforce | Stage 5 forbids enforcement |
| Analytics | Optional | Yes (gated) | Optional | |
| Crashlytics | Required (mobile) | Yes | API on + symbol scripts | Console open once |
| Performance Monitoring | Recommended | Yes | Optional | |
| Hosting | Not used by app | No | Skip | |
| Maps | Non-Firebase | Nearby UI | Out of scope | |

---

## Manual console actions (detail)

### Authentication — Email / Password

See STOP §1.

### Authentication — Google

See STOP §2.

### Authentication — Apple

See STOP §3.

### Cloud Storage

See STOP §4.

### Realtime Database

Already created:

`https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app`

Do **not** deploy `database.rules.json` in Stage 5. Start locked / default rules until a later stage.

### Cloud Messaging

Android app `com.reemove.app` is registered. Do **not** upload APNs keys in Stage 5.

### Remote Config

Already published from `remoteconfig.template.json` (keys include `maintenance_mode`, `force_update`, feature flags, `support_url`, `status_url`).

### Crashlytics

See STOP §5.

---

## Local / FlutterFire

- Staging Dart options: `lib/firebase_options_staging.dart` → `StagingFirebaseOptions`
- Native files (gitignored): `android/app/src/staging/`, `ios/config/staging/`, `macos/config/staging/` (and optional Runner copies)
- `firebase.json` → `flutter.platforms` points at staging-only outputs and `lib/firebase_options_staging.dart`
- Run example:

```bash
flutter run -d chrome \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=false \
  --dart-define=FIREBASE_DATABASE_URL=https://reemove-staging-default-rtdb.europe-west1.firebasedatabase.app
```

---

## Explicitly out of scope (Stage 5)

- Production (`reemove-production`) configuration
- Any `firebase deploy` (rules, functions, hosting, indexes)
- Enabling billing (unless owner separately approves for Storage)
- Maps, App Check enforcement, APNs
- Deploying Storage / RTDB / Firestore security rules from the repo
