# ReeMove Release Readiness Scorecard

Release candidate: ____________________  Commit: ____________________

Owner: ____________________  Date: ____________________

## Automated quality

| Gate | Required | Result | Evidence |
|---|---:|---:|---|
| Flutter format | Pass |  |  |
| Flutter analyze | Pass |  |  |
| Unit/widget tests | 100% pass |  |  |
| Functions build/tests | 100% pass |  |  |
| Firestore rules tests | 100% pass |  |  |
| Storage rules tests | 100% pass |  |  |
| Global line coverage | >= 80% |  |  |
| Critical-code coverage | >= 90% |  |  |
| Secret scan | No findings |  |  |
| Dependency review | No unaccepted high/critical risk |  |  |

## Product quality

| Gate | Required | Result | Evidence |
|---|---:|---:|---|
| Critical user journeys | 100% pass |  |  |
| Android device matrix | Pass |  |  |
| iOS device matrix | Pass |  |  |
| Offline/reconnect behavior | Pass |  |  |
| Push/deep-link behavior | Pass |  |  |
| Arabic/Hebrew/English | Pass |  |  |
| RTL layout | Pass |  |  |
| Accessibility | Pass |  |  |
| Performance budgets | Pass or approved exception |  |  |
| AI safety evaluation | Pass |  |  |

## Risk

| Gate | Required | Result | Evidence |
|---|---:|---:|---|
| Open P0 defects | 0 |  |  |
| Open P1 defects | 0 |  |  |
| High/critical security findings | 0 |  |  |
| Privacy review | Approved |  |  |
| Backup/restore rehearsal | Pass |  |  |
| Rollback rehearsal | Pass |  |  |
| Monitoring dashboards | Ready |  |  |
| Incident contacts/runbooks | Ready |  |  |

## Decision

- [ ] GO
- [ ] GO WITH APPROVED EXCEPTIONS
- [ ] NO-GO

Approved exceptions and expiration dates:

____________________________________________________________________

Product: ____________________  Engineering: ____________________

Security/Privacy: ____________________  QA: ____________________
