# Ownership and Access Handoff

## Systems requiring named owners

- Domain/DNS and public legal/support pages
- GitHub organization/repository/environments
- Firebase and Google Cloud projects/billing
- Google Maps Platform
- Apple Developer and App Store Connect
- Google Play Console
- Android signing/upload key recovery
- Apple signing/certificates/API access
- Analytics, Crashlytics, alerts, and support channels
- AI provider account, quotas, billing, and safety review
- Moderation/admin tools and legal requests

## Access principles

- Organization accounts, not a single personal mailbox
- Two recovery-capable owners
- MFA and hardware-backed methods where available
- Least privilege and quarterly review
- Separate production deployer from routine developer access
- Immediate offboarding process
- No credentials in chat, tickets, source files, screenshots, or shared documents

Use `config/ownership_matrix.csv` to record roles and evidence without recording secrets.
