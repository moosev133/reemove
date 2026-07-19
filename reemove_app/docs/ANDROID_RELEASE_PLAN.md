# Android release plan — ReeMove

## Current state

- AGP **8.11.1**, Kotlin **2.2.20**, Gradle **8.14**
- Flutter 3.44 transition flags: `android.newDsl=false`, `android.builtInKotlin=false`
- Optional upload signing when `android/key.properties` exists
- Permanent `applicationId` / namespace: **`com.reemove.app`**
- Debug APK validation previously completed after disk recovery

## Owner prerequisites

1. Confirm Play Console package `com.reemove.app` is created/owned.
2. Upload keystore + `key.properties` (never commit) — see `android/key.properties.example`.
3. Firebase Android app + `google-services.json` (local only) registered for `com.reemove.app`.
4. Maps API key (restricted to `com.reemove.app`) via `scripts/configure_google_maps.py`.
5. Local `dart_defines/prod.json` from `prod.json.example`.
6. Play Console app + App Signing enrollment (**paid developer account**).

## Local signed AAB (owner machine)

```bash
cd reemove_app
cp dart_defines/prod.json.example dart_defines/prod.json   # fill locally
# create android/key.properties
./scripts/build_android_release.sh 1.0.0 1
```

## CI path

Workflow: `.github/workflows/release-android.yml`

Secrets: `ANDROID_UPLOAD_KEYSTORE_B64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PROD_DART_DEFINES_JSON`.

## Store steps

1. Internal testing track with FCM + Maps + auth smoke on **physical devices**.
2. Closed testing → staged production (5% → 20% → 50% → 100%) per `config/release_channels.yaml`.
3. Complete Play Data safety from `config/privacy/play_data_safety.yaml`.

## Cursor scope

- **Done:** AGP opt-out flags, heap cap, optional signing DSL, INTERNET + brand label, permanent `com.reemove.app` identity, release scripts/workflows.
- **Not done:** inventing keystores or Play upload without approval.
- **Prepared:** AAB pipeline and docs; no upload without approval.
