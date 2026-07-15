# iOS Production Release Guide

## Identity and capabilities

- Finalize the bundle identifier and App Store Connect record.
- Configure Associated Domains, Push Notifications, Sign in with Apple, App Attest, Maps, background modes, and photo/camera/location usage descriptions only where required.
- Use production APNs and App Attest entitlements in release builds.
- Keep certificates, profiles, App Store Connect API keys, and recovery ownership controlled by the organization.

## Build

Use the production flavor/configuration and a unique build number for every upload.

```bash
./scripts/build_ios_release.sh 1.0.0 1
```

The script uses `flutter build ipa` with Dart obfuscation and split debug information. Preserve the `.xcarchive`, `.ipa`, dSYMs, and Dart symbols.

## App Store Connect

- Provide required metadata and select the correct build.
- Complete App Privacy details for ReeMove and every integrated third-party SDK.
- Provide a required privacy policy URL.
- Complete age rating and accessibility information accurately.
- Give App Review a test account and precise instructions for gated features, moderation, nearby/location behavior, marketplace, messaging, and AI modules.
- Use TestFlight before public release.

## Review readiness

The review account must contain safe sample content and must not depend on unavailable real-world events. Backend services must remain available throughout review. Explain any feature flag or region limitation in Review Notes.
