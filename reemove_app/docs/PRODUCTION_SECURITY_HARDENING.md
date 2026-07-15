# Production Security Hardening

## Required controls

- Least-privilege IAM roles; no shared owner accounts for daily work
- Mandatory multi-factor authentication for Firebase, Google Cloud, GitHub, Apple, and Play Console
- Two independent organization owners with documented recovery paths
- Protected branches/tags/environments and required reviewers
- Short-lived CI credentials through Workload Identity Federation where supported
- Secret Manager for backend secrets; encrypted store/CI secrets for signing material
- App Check plus Firebase Authentication; neither replaces Security Rules
- Deny-by-default Firestore and Storage rules with emulator tests
- Rate limits, idempotency, validation, moderation, and audit logs for sensitive Functions
- Restricted API keys and budget/quota alerts
- No personal data in logs, Crashlytics keys, analytics parameters, or notification payloads

## Mobile hardening

- Release mode only; remove debug menus and emulator endpoints
- `--obfuscate` and `--split-debug-info` with symbol retention
- Android R8/resource shrinking after regression testing
- iOS release signing and production entitlements only
- Modern TLS through platform networking; no trust-all certificates
- Secure local storage for tokens; no secrets in assets or Dart defines
- Screenshot/privacy controls only where they do not break legitimate accessibility/OS behavior
- Runtime feature flags fail safe when Remote Config is unavailable

## Social-platform safety

Before production, verify report, block, mute, moderation, appeal, content removal, account deletion, and support escalation. Youth-facing experiences must not expose precise location by default, and nearby matching must enforce privacy rules from earlier phases.

## Pre-release scans

- Dependency vulnerability review
- Repository secret scan including Git history
- Android manifest and iOS entitlement review
- Rules tests and unauthenticated negative tests
- API abuse/rate-limit tests
- AI safety regression suite
- Privacy/data inventory diff against store declarations
