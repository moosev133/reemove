# Profile verification setup

## Purpose

ReeMove verification is an identity and role-review workflow, not a client-controlled badge. The production process must combine the checked-in technical controls with an approved internal review policy.

## Firebase requirements

1. Deploy the Phase 7 Firestore Rules, Storage Rules, Functions, and indexes.
2. Ensure administrators receive a trusted Firebase Auth custom claim:

```json
{"admin": true}
```

3. Never allow the client to set or request this claim directly.
4. Restrict access to the Firebase project and verification evidence bucket to the smallest operational team.
5. Enable audit-log retention and alerts for verification reviews.

Custom-claim changes require the reviewer to refresh their ID token before the app sees new privileges.

## Storage paths

Private evidence is uploaded under:

```text
verification/{uid}/{requestId}/{assetId}
```

The current client uses the authenticated UID as the request ID until a pending request is created. Files require owner/path-bound metadata and are readable only by the owner through client rules. Administrative review should use the trusted backend/Admin SDK rather than weakening client Storage Rules.

Allowed evidence should be limited by the product policy. The checked-in rules support reviewed image content types and bounded sizes; verify the final MIME list against the actual app-store privacy declarations before release.

## Review workflow

1. User selects athlete, trainer, or business verification.
2. User provides legal name, summary, and evidence.
3. `submitVerificationRequest` validates ownership and creates a pending server-owned record.
4. An internal review tool calls `reviewVerificationRequest` as an authenticated administrator.
5. Approval updates profile verification, role, and custom claims.
6. Rejection stores a user-visible reason without exposing internal reviewer notes.
7. Every decision writes an audit event with reviewer UID, target UID, action, and timestamp.

The mobile app intentionally does not contain an administrator review screen in Phase 7. Build the internal moderation console in a controlled operations environment before production verification is enabled.

## Policy decisions required before launch

- Evidence types accepted for athletes, trainers, and businesses.
- Regional age and guardian requirements.
- Data retention and secure deletion period.
- Reviewer training and escalation path.
- Fraud, impersonation, and appeal policy.
- Badge revocation policy.
- Whether role verification implies credentials, identity, achievement, or only account authenticity.

Do not describe a badge more broadly than the evidence actually reviewed.

## Release checklist

- Rules tests pass in the Firebase emulators.
- Only administrators can review requests.
- Non-admin callable attempts are rejected.
- Owners can read their request; unrelated users cannot.
- Evidence cannot be listed or read by unrelated clients.
- Removing an unsubmitted evidence image deletes its Storage object.
- A scheduled lifecycle policy removes abandoned draft evidence after the approved retention window.
- Forged owner metadata and cross-user paths fail.
- Approval and rejection are idempotent and audited.
- Custom claims refresh correctly on a physical device.
- Profile author snapshots update after approval.
- Evidence retention/deletion behavior is tested.
- Privacy policy and store declarations describe the collected evidence.
