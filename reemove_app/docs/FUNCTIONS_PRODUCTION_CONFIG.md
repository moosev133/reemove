# Functions Production Configuration

Use typed parameters and Secret Manager for required values. Examples to define in the merged Functions code include:

- Environment name
- Public app/support/status URLs
- AI provider secret and model allowlist
- Maps/server credentials only where required
- Per-user/per-IP quota thresholds
- Moderation configuration
- Email/provider configuration
- Retention and scheduled-job settings

Do not commit real `.env.prod` or `.secret.local` files. Validate startup fails closed when a required production parameter is missing.
