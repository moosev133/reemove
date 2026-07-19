# iOS release plan — ReeMove

## Current state

- Permanent bundle ID: **`com.reemove.app`**
- Privacy usage strings updated for camera / photos / location
- Display name set to **ReeMove**
- Associated Domains scaffolding for `applinks:links.reemove.app`
- `ios/ExportOptions.plist.template` present; filled plist stays local / CI secret
- Capabilities checklist: `docs/IOS_PRODUCTION_CAPABILITIES_CHECKLIST.md`
- No certificates invented in this audit

## Owner prerequisites (Apple Developer — paid)

1. Register App ID `com.reemove.app` in the Apple Developer portal (already set in Xcode project).
2. Capabilities: Push Notifications, Background Modes → Remote notifications, Sign in with Apple, Associated Domains, App Attest (as required).
3. Distribution certificate + App Store provisioning profile.
4. `ExportOptions.plist` from template (team ID, method `app-store-connect`).
5. `GoogleService-Info.plist` via FlutterFire (never commit) for `com.reemove.app`.
6. APNs auth key uploaded to Firebase Cloud Messaging.
7. Local `dart_defines/prod.json` with production defines.
8. Maps iOS key applied (script / xcconfig), restricted to `com.reemove.app`.

## Local IPA (owner Mac)

```bash
cd reemove_app
cp dart_defines/prod.json.example dart_defines/prod.json   # fill locally
cp ios/ExportOptions.plist.template ios/ExportOptions.plist # fill locally
./scripts/build_ios_release.sh 1.0.0 1
```

## CI path

Workflow: `.github/workflows/release-ios.yml`  
Secrets: `PROD_DART_DEFINES_JSON`, `IOS_EXPORT_OPTIONS_PLIST`, plus org signing install step (currently stub — owner must finish).

## TestFlight

1. Upload IPA to App Store Connect.
2. Internal testing → external beta.
3. Physical device smoke (push, Maps, Sign in with Apple, deep links).
4. Privacy questionnaire from `config/privacy/app_store_privacy_answers.yaml`.

## Cursor scope

- Docs, templates, branding/privacy copy updates.
- **No** certificate generation, **no** App Store upload without explicit approval.
