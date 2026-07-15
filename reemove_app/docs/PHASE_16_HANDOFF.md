# Phase 16 Handoff — Deployment and Production Release

Phase 16 may begin after Phase 15 release gates are implemented and a release candidate has completed the scorecard.

## Inputs Phase 16 needs

- Signed release readiness scorecard
- Final supported OS/device matrix
- Test and coverage reports
- Security/privacy approval and open-risk register
- Performance baselines and alert thresholds
- Firebase rules/functions/indexes proven in staging
- App Check rollout status and metrics
- Store metadata/privacy answers
- Backup, restore, rollback, and incident runbooks
- Release signing ownership and access plan

## Phase 16 work

1. Create or verify isolated production Firebase project and billing safeguards.
2. Configure production Authentication providers, domains, indexes, Storage, Functions, FCM, App Check, Crashlytics, Performance, Analytics/consent, and Remote Config.
3. Configure Android and Apple signing, bundle identifiers, entitlements, universal/app links, maps keys, and push credentials.
4. Build hardened CI/CD with protected environments and short-lived cloud authentication.
5. Generate signed release artifacts and store listings.
6. Distribute internal/closed testing builds.
7. Run production-config smoke tests and rollback rehearsal.
8. Launch with staged rollout, dashboards, alerts, support process, and incident ownership.
9. Review early metrics and expand rollout only when gates remain healthy.

## Do not carry forward

- Debug App Check tokens
- Emulator host configuration
- Test users or synthetic seed data
- Placeholder API keys or secrets
- Verbose sensitive logging
- Disabled certificate/transport checks
- Unreviewed third-party workflow actions
- Temporary broad Firebase rules
