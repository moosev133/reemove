# iOS Production Capabilities Checklist

- Bundle identifier matches Firebase and App Store Connect
- Push Notifications and APNs configured
- Sign in with Apple capability configured
- Associated Domains match hosted `apple-app-site-association`
- App Attest environment is production
- Background modes include only genuinely required modes
- Privacy usage descriptions match final permission behavior
- Required privacy manifests and third-party SDK signatures are present
- Universal links tested from installed, background, and terminated states
- No development/debug entitlements in the archive
