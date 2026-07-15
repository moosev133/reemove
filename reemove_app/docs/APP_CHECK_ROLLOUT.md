# App Check Rollout

1. Register production Android and Apple apps with the selected real attestation providers.
2. Release an internal build with App Check enabled but backend enforcement disabled.
3. Review valid/invalid/unknown request metrics for Authentication, Firestore, Storage, and Functions.
4. Resolve old builds, misconfigured signing fingerprints, simulator/debug traffic, and unsupported-device strategy.
5. Enforce one product at a time, starting with the highest-risk backend after metrics are healthy.
6. Watch errors and support signals; roll back enforcement if legitimate users are blocked.
7. Delete production debug tokens and prohibit debug provider activation in release mode.
