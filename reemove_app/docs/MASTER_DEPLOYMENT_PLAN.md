# Master Deployment Plan

## Release principle

Production is a controlled promotion of an already-tested release candidate. Do not use production to discover configuration, migration, or policy problems.

## Environments

| Environment | Purpose | Data | App Check | Deployment |
|---|---|---|---|---|
| dev | Local development and emulator work | Synthetic | Debug provider only | Developer initiated |
| staging | Production-like integration and beta validation | Synthetic/consented testers | Real providers, monitored then enforced | Automatic from protected staging branch |
| prod | Public users | Real user data | Real providers, monitored then enforced | Manual approval from immutable release tag |

Each environment uses a separate Firebase project. Production data must never be copied into dev. Use anonymized fixtures where representative data is required.

## Release train

1. Merge to `main` only after Phase 15 PR gates pass.
2. Create `release/x.y.z` and freeze schema-changing work.
3. Deploy backend/rules/indexes to staging.
4. Build signed release candidates using staging and production configurations separately.
5. Run manual QA, Test Lab/device tests, privacy verification, and rollback rehearsal.
6. Tag the approved commit as `vX.Y.Z`.
7. Deploy production backend through a protected environment approval.
8. Release to internal/TestFlight testing.
9. Promote to a small production percentage.
10. Expand in measured steps only if SLOs and support signals remain healthy.

## First-launch rollout

Recommended gates are 5%, 20%, 50%, then 100%. Stay at each gate long enough to collect meaningful crash, latency, authentication, messaging, upload, moderation, notification, and account-deletion evidence. Stop or reverse promotion when any rollback trigger is met.

## Immutable release evidence

Store for every release:

- Git commit and signed tag
- Flutter/Dart/Java/Xcode versions
- Dependency lockfiles
- Phase 15 reports and signoffs
- Backend deployment logs
- AAB/IPA checksums
- Dart split-debug-info and Apple dSYM files
- Store submission metadata and privacy answers
- Remote Config version/export
- Rollout approvals and incident notes
