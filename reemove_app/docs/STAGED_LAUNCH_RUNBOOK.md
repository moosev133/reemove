# Staged Launch Runbook

## T-7 to T-1 days

- Sign Phase 15 scorecard
- Freeze release scope
- Confirm store metadata/privacy declarations
- Complete beta and production-config smoke test
- Verify monitoring, alerts, backups, support, moderation, and incident rota
- Export Remote Config and verify kill switches
- Validate reviewer credentials and backend availability

## Launch day

1. Deploy approved production backend/rules/indexes.
2. Run post-deploy smoke checks.
3. Release to internal/TestFlight/Play internal group.
4. Confirm crash/symbolication, auth, feed, upload, message, notification, maps, challenge, marketplace, AI, report/block, and deletion flows.
5. Start production rollout at the first gate.
6. Record approver, time, version, build, commit, config version, and dashboard links.

## Expansion decision

At every gate review:

- Phase 15 critical journeys remain healthy
- No P0/P1 defect or high/critical security issue
- Crash-free and performance thresholds pass
- Error, quota, cost, moderation, and support signals are acceptable
- Store reviews do not reveal a systemic issue

Document “promote”, “hold”, or “rollback” with owner and evidence.
