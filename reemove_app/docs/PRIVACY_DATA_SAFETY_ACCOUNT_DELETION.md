# Privacy, Data Safety, and Account Deletion

This is an implementation checklist, not legal advice. Final documents and retention decisions require review for the countries where ReeMove operates.

## Single source of truth

Maintain `config/privacy/data_inventory.csv` as the source for:

- Data collected
- Purpose
- Whether linked to a user
- Whether shared
- Retention
- Deletion behavior
- SDK/controller responsible
- Store disclosure mapping

Update the App Store privacy answers and Google Play Data safety form whenever the app or SDK behavior changes.

## Likely ReeMove categories to verify

Account identifiers, profile information, user-generated photos/videos/text, messages, approximate/precise location choices, contacts only if truly used, device/app identifiers, diagnostics, usage analytics, marketplace content, support requests, moderation reports, and AI prompts/results. Do not mark a category solely from this list; confirm the final code and SDKs.

## Account deletion

- Provide an in-app deletion flow.
- Provide a public deletion/help URL required by the applicable store policy.
- Re-authenticate for destructive action when appropriate.
- Explain immediate effects and any legally required retention.
- Disable access promptly, revoke tokens/sessions, and enqueue deletion jobs.
- Delete or anonymize profile, social graph, posts, stories, messages according to the approved model, uploads, listings, notifications, AI records, and derived indexes.
- Preserve only documented data required for fraud, security, disputes, or law, with access restrictions and expiry.
- Give the user a request reference and completion status without exposing sensitive data.
- Test idempotency and partial-failure recovery.

## Youth and location

Use age-appropriate defaults, avoid public precise location, minimize location retention, and clearly distinguish location used on-device, used for a live request, or stored. Do not infer or advertise safety guarantees that the implementation cannot enforce.
