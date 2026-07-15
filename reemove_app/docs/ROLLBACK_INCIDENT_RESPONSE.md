# Rollback and Incident Response

## Rollback layers

1. Remote Config kill switch for a failing optional feature
2. Stop staged store rollout
3. Backend rollback to the previous tagged Functions/rules/indexes configuration
4. Minimum-version/update messaging only when a secure fixed version is available
5. Maintenance mode for severe platform-wide risk
6. Data repair from an approved migration/recovery procedure

A mobile binary already installed cannot be instantly removed. Design backend compatibility for at least the previous supported app version.

## Rollback triggers

- P0 security/privacy exposure
- Authentication or account deletion broadly failing
- Crash-free users below threshold
- Severe data corruption or authorization bypass
- Messaging/nearby/location behavior exposing private data
- AI safety gate regression
- Uncontrolled cost/abuse that cannot be rate-limited safely
- Store/policy instruction requiring immediate action

## Incident roles

- Incident commander
- Engineering lead
- Security/privacy lead
- Product/customer communications lead
- Scribe/evidence owner

## First actions

1. Confirm impact without collecting unnecessary personal data.
2. Freeze unrelated deployments.
3. Apply the safest reversible containment.
4. Preserve logs/audit evidence.
5. Communicate status through approved channels.
6. Validate recovery with production-safe checks.
7. Document root cause, corrective actions, owners, and deadlines.
