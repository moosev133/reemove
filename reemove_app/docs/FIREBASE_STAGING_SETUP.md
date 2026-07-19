# Firebase Staging Setup — `reemove-staging`

**Scope:** Staging project only. Never apply these steps to `reemove-production` in this stage.  
**Do not deploy** rules, indexes, Functions, Hosting, or Storage rules from this stage.  
**Related:** `docs/FLUTTERFIRE_STAGING.md` (FlutterFire apps + Dart options).

---

## Service dependency matrix

| Service | Required | Implemented in app | Staging console status | Notes |
|---------|----------|--------------------|------------------------|-------|
| Authentication (Email, Google, Apple) | Required | Yes | **Manual** | Providers + OAuth / Apple + authorized domains |
| Cloud Firestore | Required | Yes | **Manual** | API + create DB (rules deploy is a later stage) |
| Cloud Storage | Required | Yes | **Manual** | Default bucket; rules deploy later |
| Realtime Database | Required (presence/typing) | Yes | **Manual** | Create instance; set `FIREBASE_DATABASE_URL` |
| Cloud Functions | Required | Yes (`europe-west1`) | **Manual later** | Do **not** deploy in Stage 5 |
| Cloud Messaging (FCM) | Required | Yes | **Manual** | Android works with google-services; APNs later |
| Remote Config | Required | Yes | **Manual** | Publish from `remoteconfig.template.json` in console or later deploy |
| App Check | Optional now / required before enforcing callables | Yes (gated) | **Manual later** | Do **not** enforce in Stage 5 |
| Analytics | Optional (`ENABLE_ANALYTICS`) | Yes (gated) | **Manual** | Link GA4 if desired |
| Crashlytics | Required (mobile) | Yes | **Manual** | Enable in console |
| Performance Monitoring | Recommended | Yes | **Manual** | Enable in console |
| Hosting | Not used by app | No | Skip | Deep links hosted externally |
| Maps | Non-Firebase | Nearby UI | Out of scope | Stage 5 forbids Maps setup |

**Already done (CLI / prior stages):** FlutterFire Android / iOS / Web apps for `com.reemove.app` on `reemove-staging`; staging Dart options wired.

**CLI this stage:** No additional cloud mutations (gcloud not installed; Firebase CLI cannot enable Auth providers or create Firestore without the API). Setup is **console-driven** per the checklist below.

---

## Manual console actions (owner)

Use Google account that owns **`reemove-staging`**.  
Console base: [Firebase Console](https://console.firebase.google.com/) → select project **ReeMove Staging** (`reemove-staging`).

### 1. Enable Cloud Firestore API + create database

**Why:** App data plane (profiles, feed, messaging metadata, marketplace, etc.). Currently the Firestore API returns 403 until enabled.

**Path:**

1. Open [Google Cloud APIs — Firestore](https://console.developers.google.com/apis/api/firestore.googleapis.com/overview?project=reemove-staging) → **Enable**.
2. Firebase Console → **Build** → **Firestore Database** → **Create database**.
3. Choose production mode **or** test mode temporarily; **location:** prefer a region compatible with Functions (`europe-west1` / multi-region `eur3` if offered — pick one and keep it forever).
4. Finish create. **Do not** deploy repo rules yet (later stage).

**Settings:** Native mode (not Datastore). Remember the location ID for ops docs.

---

### 2. Authentication — Email / Password

**Why:** Primary sign-up / sign-in path in `firebase_auth_repository.dart`.

**Path:** Firebase Console → **Build** → **Authentication** → **Get started** (if first time) → **Sign-in method** → **Email/Password**.

**Settings:**

- Enable **Email/Password**.
- Leave Email link (passwordless) **disabled** unless product asks for it later.
- **Settings** → **Authorized domains**: ensure `localhost`, your staging web domain (when known), and `reemove-staging.firebaseapp.com` are listed.

---

### 3. Authentication — Google

**Why:** Google Sign-In on mobile/web; needs Web client ID in dart-defines (`GOOGLE_SERVER_CLIENT_ID`).

**Path:** Authentication → **Sign-in method** → **Google** → Enable.

**Settings:**

- Support email: your owner email.
- After enable, open [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials?project=reemove-staging) and note the **Web client ID** (OAuth 2.0 Client IDs).
- Put that value into local `dart_defines/staging.json` as `GOOGLE_SERVER_CLIENT_ID` (gitignored).
- Android: add SHA-1 / SHA-256 of debug (and later upload) keystore under Project settings → Your apps → Android app.

---

### 4. Authentication — Apple

**Why:** Sign in with Apple on iOS (and optionally other platforms).

**Path:** Authentication → **Sign-in method** → **Apple** → Enable.

**Settings:**

- Requires Apple Developer Services ID, Team ID, Key ID, and private key (owner credentials — never commit).
- Bundle ID must match `com.reemove.app`.
- Complete Apple Developer “Sign in with Apple” capability for the App ID (Xcode / developer.apple.com).

---

### 5. Cloud Storage — default bucket

**Why:** Avatars, posts, stories, chat media, marketplace, challenges.

**Path:** Firebase Console → **Build** → **Storage** → **Get started**.

**Settings:**

- Start in production mode rules (or temporary rules); **do not** deploy repo `storage.rules` in Stage 5.
- Location: align with project / Firestore when possible.
- Confirm bucket name (expected pattern: `reemove-staging.firebasestorage.app` or `*.appspot.com`).

---

### 6. Realtime Database

**Why:** Messaging presence and typing (`presence/`, `typing/` paths).

**Path:** Firebase Console → **Build** → **Realtime Database** → **Create Database**.

**Settings:**

- Location: choose a supported region (document it).
- Start in locked mode; **do not** deploy `database.rules.json` in Stage 5.
- Copy the database URL (e.g. `https://reemove-staging-default-rtdb.<region>.firebasedatabase.app`) into local `dart_defines/staging.json` as `FIREBASE_DATABASE_URL`.

---

### 7. Cloud Messaging

**Why:** Push + device registration for notifications / messaging.

**Path:** Firebase Console → **Engage** / **Messaging** (or Project settings → Cloud Messaging).

**Settings (Stage 5 — Android-focused):**

- Confirm Android app `com.reemove.app` is listed (already registered).
- **Do not** upload APNs keys in Stage 5 (explicitly deferred).
- Optional: create a test notification later after Auth works.

---

### 8. Remote Config — publish template parameters

**Why:** Maintenance mode, force-update, feature flags (`release_control_service.dart`).

**Path:** Firebase Console → **Engage** → **Remote Config** → create/edit parameters.

**Settings:** Manually mirror keys from repo file `remoteconfig.template.json`, including at least:

- `maintenance_mode`, `maintenance_title`, `maintenance_message`
- `force_update`, `minimum_supported_android_build`, `minimum_supported_ios_build`
- `recommended_android_build`, `recommended_ios_build`
- Feature flags: `ai_modules_enabled`, `nearby_enabled`, `marketplace_enabled`, `messaging_enabled`, `story_upload_enabled`, etc.

**Publish** changes in the console. Do **not** run `firebase deploy --only remoteconfig` in Stage 5 unless a later stage explicitly approves deploy.

---

### 9. Crashlytics

**Why:** Mobile crash reporting when Firebase is ready.

**Path:** Firebase Console → **Release & Monitor** → **Crashlytics** → Enable for Android / iOS apps.

**Settings:** Follow onboarding prompts for the registered apps. dSYM / mapping uploads come with release builds later.

---

### 10. Performance Monitoring (recommended)

**Why:** Traces in observability wrappers.

**Path:** **Release & Monitor** → **Performance** → Enable.

---

### 11. Analytics (optional for staging)

**Why:** Gated by `ENABLE_ANALYTICS` (staging example defaults to `false`).

**Path:** **Analytics** → enable / link GA4 property if you want staging telemetry.

**Settings:** Keep staging analytics off in dart-defines until privacy review is ready.

---

### 12. App Check (prepare only — do not enforce)

**Why:** Callables are coded with `enforceAppCheck: true` on the backend; enforcement before debug tokens will break staging clients.

**Path:** **Build** → **App Check** → register providers (Play Integrity, DeviceCheck/App Attest, reCAPTCHA v3 for web).

**Settings for Stage 5:**

- Register apps in **monitoring** / debug mode only.
- Add debug tokens for local Chrome / emulators as needed.
- **Do not** turn on enforcement for Auth / Functions / Firestore / Storage yet.

---

### 13. Cloud Functions — do not deploy yet

**Why:** Backend is implemented under `functions/` but Stage 5 forbids deploy.

**Later path (not now):** Blaze billing (owner), secrets (`OPENAI_API_KEY`, etc.), then `firebase deploy --only functions --project reemove-staging` with explicit approval.

---

### 14. Google Cloud APIs (if Firestore / others 403)

If CLI or Console shows “API has not been used / disabled”:

1. Open [API Library for reemove-staging](https://console.cloud.google.com/apis/library?project=reemove-staging).
2. Enable at minimum:
   - Cloud Firestore API
   - Identity Toolkit API
   - Token Service API
   - Cloud Storage for Firebase API
   - FCM API
   - Firebase Remote Config API
   - Firebase Crashlytics API
   - Cloud Functions API (before any future Functions deploy)

---

## Local dart-defines (owner machine)

Copy `dart_defines/staging.json.example` → `dart_defines/staging.json` (gitignored) and fill:

| Key | Staging expectation |
|-----|---------------------|
| `APP_FLAVOR` | `staging` |
| `GOOGLE_SERVER_CLIENT_ID` | Web OAuth client from staging Google Cloud |
| `FIREBASE_DATABASE_URL` | RTDB URL after step 6 |
| `FIREBASE_WEB_RECAPTCHA_V3_SITE_KEY` | Only when App Check web is prepared |
| `ENABLE_APP_CHECK` | `false` until debug tokens + monitoring are ready |
| `ENABLE_ANALYTICS` | `false` recommended for early staging |

---

## Validation commands (after console steps)

```bash
cd reemove_app
flutter analyze
flutter test
flutter run -d chrome \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=ENABLE_APP_CHECK=false \
  --dart-define=ENABLE_ANALYTICS=false \
  --dart-define=USE_FIREBASE_EMULATORS=false
```

Confirm logs / runtime options use **`reemove-staging`** only (never `reemove-production`).

---

## Explicitly out of scope for Stage 5

- Deploying Firestore / Storage / RTDB rules or indexes  
- Deploying Cloud Functions or Hosting  
- Enabling billing / Blaze  
- Maps API keys  
- App Check **enforcement**  
- APNs upload  
- Any change to `reemove-production`
