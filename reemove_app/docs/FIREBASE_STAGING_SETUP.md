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
| Authentication | **Blocked** — Auth config not initialized; Identity Platform `initializeAuth` requires billing; use Console **Get started** (Spark) |
| Auth providers (Email / Google / Apple) | **Console only** (after Auth Get started) |
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

### 1. Authentication — Get started + Email / Password

**Why:** API Auth config is missing (`CONFIGURATION_NOT_FOUND`). Identity Platform programmatic init requires billing; Firebase Console **Get started** initializes classic Firebase Auth on Spark.

**Path:** Build → **Authentication** → **Get started** → **Sign-in method** → **Email/Password** → Enable (password required). Leave Email link disabled unless product asks later.

**Authorized domains:** keep `localhost`, `reemove-staging.firebaseapp.com`, and any staging web host.

### 2. Authentication — Google

**Path:** Sign-in method → **Google** → Enable (support email = owner).

Then note the **Web client ID** from [Credentials](https://console.cloud.google.com/apis/credentials?project=reemove-staging) → put in local `dart_defines/staging.json` as `GOOGLE_SERVER_CLIENT_ID`.  
Add Android debug SHA-1 / SHA-256 under Project settings → Android app.

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
