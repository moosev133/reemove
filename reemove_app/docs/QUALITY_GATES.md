# Quality Gates and Release Criteria

## Pull request gates

Every pull request must pass:

- Format and static analysis
- Unit and widget tests for affected code
- Functions build and tests when backend code changes
- Rules tests when Firestore or Storage rules/schema changes
- Secret scan
- Manifest/package validation
- New or updated acceptance tests for changed critical behavior

## Main branch gates

Main must additionally pass:

- Full Flutter coverage collection
- All Firebase emulator tests
- Contract compatibility tests
- Android integration smoke suite
- Build of Android release artifacts without signing secrets

## Nightly gates

Nightly runs add:

- Broader integration suite
- Multiple Android API levels and form factors
- iOS simulator/hosted device suite when available
- Performance smoke profiling
- AI regression evaluation
- Dependency and vulnerability review
- Firebase Test Lab matrix as budget allows

## Release candidate gates

- 100% critical journeys pass.
- Zero P0 and P1 defects.
- Zero unaccepted critical/high security findings.
- Security Rules fail closed for unauthorized users.
- App Check metrics have been reviewed before enforcement changes.
- Crash-free, latency, and resource budgets are defined and monitored.
- Accessibility and Arabic/Hebrew RTL checks pass.
- Store privacy declarations match actual data collection.
- Backup, restore, rollback, and incident response are rehearsed.

## Coverage interpretation

Coverage is a guardrail, not proof. Exclude generated Firebase configuration, localization output, and generated serialization only. Do not exclude difficult domain, authorization, moderation, or error-handling code merely to raise the percentage.

## Exception format

Every exception must include:

- Failed gate and measured value
- User/business impact
- Why release is still acceptable
- Temporary mitigation
- Owner
- Expiration date
- Tracking issue
- Explicit approvers
