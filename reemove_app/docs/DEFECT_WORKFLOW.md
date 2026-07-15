# Defect Workflow

## Severity

- P0: security/privacy breach, widespread crash, data loss/corruption, account takeover, or release completely unusable.
- P1: critical journey blocked, unauthorized access with limited scope, major reliability failure, or unsafe AI behavior.
- P2: significant feature defect with workaround or substantial visual/accessibility issue.
- P3: minor defect, polish, or low-impact edge case.

## Required defect fields

- Title and severity
- Build/commit/environment
- Device, OS, locale, theme, network
- Preconditions and test account role
- Reproduction steps
- Expected and actual result
- Frequency
- Screenshots/video/logs with sensitive data removed
- Suspected area and owner
- User and business impact

## Lifecycle

New → Triaged → In Progress → Ready for Verification → Verified → Closed.

Reopened defects return to In Progress. Deferred defects require product and engineering approval plus target milestone.

## Closure

- Fix merged
- Appropriate automated regression test added
- Manual verification completed when needed
- No sensitive logs attached
- Related documentation or monitoring updated
