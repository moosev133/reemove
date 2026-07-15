# Observability, SLOs, and Alerts

## Release health dashboard

Track by app version, platform, country/locale, and rollout cohort where privacy-safe:

- Crash-free users and sessions
- Fatal and non-fatal issue rate
- Cold/warm startup P95
- Feed first-content and pagination P95
- Message acknowledgement P95
- Callable error rate and P95, including AI callables separately
- Auth success/failure by provider
- Upload failure and media-processing backlog
- Notification delivery/open and deep-link failures
- Firestore/Functions quota, latency, error, and cost signals
- App Check valid/invalid/unknown traffic
- Account deletion queue age/failure
- Moderation/report queue age
- Store rating/support volume and top complaints

## Initial release thresholds

Use `config/monitoring_thresholds.json` as starting values, then replace them with measured baselines. Phase 15 performance budgets remain release-blocking.

## Alert routing

- P0: page engineering/on-call and product owner immediately
- P1: alert within minutes and assign incident lead
- P2: create tracked issue during business hours
- Cost/budget: alert engineering and account owner before hard limits affect users

## Privacy

Do not attach names, emails, message text, exact coordinates, auth tokens, AI prompts, or user-generated content to logs or Crashlytics. Use generated request IDs and coarse, approved diagnostic attributes.
